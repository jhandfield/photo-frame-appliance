# Simple Photo Frame Appliance

A simple, plug-and-play slideshow appliance for Raspberry Pi and other devices.

* Automatically starts a fullscreen slideshow of images in your configured photos directory (default: `~/Pictures`) on boot
* Watches for new images and restarts the slideshow automatically
* Shows a static error image if the slideshow repeatedly fails

Designed to be minimal, reliable, and easy to set up.

---

## Features

* Fullscreen slideshow using the framebuffer (`fbi`)
* Automatic restart on new images (debounced to avoid disruptions on bulk uploads)
* Automatic HEIC to JPEG conversion (runs independently without debouncing)
* Failure handling with a static error image
* Automatic power-off at 10pm (22:00) local time
* Compatible with Raspberry Pi OS and Ubuntu Server and other Debian-based systems
* Minimal dependencies (`fbi`, `psmisc`, `inotify-tools`, `imagemagick`)

---

## Repository Structure

```
photo-frame-appliance/
├── install.sh                 # Installer script
├── uninstall.sh               # Uninstaller script
├── scripts/
│   ├── photos-watch.sh        # Watches /photos for new images and restarts slideshow
│   ├── photos-convert.sh      # Converts unsupported formats (HEIC) to JPEG
│   └── show-error-image.sh    # Displays error image if slideshow fails
│   └── start-slideshow.sh     # Starts the slideshow
├── units/
│   ├── slideshow.service
│   ├── photos-watch.service
│   ├── photos-convert.service # Runs photos-convert.sh continuously
│   └── slideshow-error.service
│   └── boot-splash.service    # Optional boot splash (coming soon)
├── splash/
│   └── splash.png             # Optional default splash image
│   └── error-day.png          # Static error image, displayed during the day (6am-6pm system time)
│   └── error-night.png        # Static error image, displayed at night (6pm-6am system time)
└── README.md
```

---

## Installation

1. **Clone the repository**:

```bash
git clone https://github.com/jhandfield/photo-frame-appliance.git
cd photo-frame-appliance
```

2. **(Optional) Customize configuration**:

The installer uses sensible defaults that work for most users. To customize settings:

* Copy `config.sh.example` to `config.sh`
* Edit the values in `config.sh`

Available settings:
* `PHOTOS_DIR` - Where photos are stored (default: RUN_USER's `~/Pictures`, e.g., `/home/alice/Pictures`)
* `SPLASH_DIR` - Where splash/error images are stored (default: `/boot/splash`) **Don't override this unless you really know what you're doing!**
* `SLIDESHOW_INTERVAL` - Seconds to display each photo (default: `300` = 5 minutes)
* `RUN_USER` - User to run services as (default: current user)
* `RUN_GROUP` - Group to run services as (default: current user's group)
* `AUTO_POWEROFF_ENABLED` - Enable daily automatic poweroff (default: `true`)
* `AUTO_POWEROFF_TIME` - Time to power off in HH:MM format (default: `22:00`)

3. **Run the installer as root**:

```bash
sudo ./install.sh
```

The installer will:

* Install required packages: `fbi`, `psmisc`, `inotify-tools`, `imagemagick`
* Create the photos and splash directories as configured
* Copy scripts and systemd service units
* Enable and start the slideshow, slideshow-error, and photo-watch services
* Configure automatic daily poweroff (if enabled)

---

## Adding Images

1. Place your images in your configured directory (default: `/home/<your-user>/Pictures`):

```bash
cp ~/my-photos/*.jpg ~/Pictures/
chmod 644 ~/Pictures/*.jpg
```

2. The slideshow will automatically start on boot, and **restart whenever new images are added** (debounced by 30 seconds to reduce disruptions if you're uploading a large batch of images at once).

3. **HEIC files are automatically converted to JPEG** by the `photos-convert` service. The service runs continuously and converts all `.heic` and `.HEIC` files found in `/photos` to `.jpg` format. Original HEIC files are preserved to support tools like rsync for syncing external sources.

---

## Optional Boot Splash (not yet implemented)

To enable a custom boot splash before the slideshow:

1. Place a splash image in `/boot/splash/splash.jpg`
2. Enable the boot splash service:

```bash
sudo systemctl enable boot-splash.service
```

> Note: On Raspberry Pi, this will display a static image before the slideshow starts. On other systems, ensure `/dev/fb0` exists.

---

## Error Handling

If the slideshow fails repeatedly (default: 5 failures within 120 seconds):

* `slideshow-error.service` will start automatically
* Displays `/boot/splash/error.jpg` indefinitely
* Kills any other processes using the framebuffer

If you wish to change the error images displayed, replace the files `/boot/splash/error-day.png` and `/boot/splash/error-night.png`.

---

## User & Permissions

* By default, all services run as the user who invoked `sudo ./install.sh`
* The user must belong to the `video` group to access the framebuffer:

```bash
sudo usermod -aG video $USER
```

* To customize the user/group, create a `config.sh` file (see Installation section above) and set `RUN_USER` and `RUN_GROUP` before running the installer

---

## Troubleshooting

* **Slideshow doesn’t start**: Check if `/dev/fb0` exists and user has access.
* **New images not triggering slideshow restart**: Ensure `inotify-tools` is installed.
* **Error screen appears unexpectedly**: Check `journalctl -u slideshow.service` and `/usr/local/bin/show-error-image.sh`.

View logs:

```bash
journalctl -u slideshow.service
journalctl -u photos-watch.service
journalctl -u slideshow-error.service
```

---

## AI Disclaimer

This software was written utilizing the following tools:
* ChatGPT (GPT-5 model, December 2025)
* GitHub Copilot:
  * GPT-5.1-Codex-Max model, December 2025
  * Claude Haiku 4.5 model, December 2025

All suggestions were human-reviewed and tested.

---

## License

This project is licensed under the MIT License. Feel free to fork and modify for personal projects or educational purposes.