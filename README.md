# Simple Photo Frame Appliance

A simple, plug-and-play slideshow appliance for Raspberry Pi and other devices.

* Automatically starts a fullscreen slideshow of images in `/photos` on boot
* Watches for new images and restarts the slideshow automatically
* Shows a static error image if the slideshow repeatedly fails

Designed to be minimal, reliable, and easy to set up.

---

## Features

* Fullscreen slideshow using the framebuffer (`fbi`)
* Automatic restart on new images (debounced)
* Failure handling with a static error image
* Compatible with Raspberry Pi OS and Ubuntu Server and other Debian-based systems
* Minimal dependencies (`fbi`, `psmisc`, `inotify-tools`)

---

## Repository Structure

```
photo-frame-appliance/
├── install.sh                 # Installer script
├── uninstall.sh               # Uninstaller script
├── scripts/
│   ├── photos-watch.sh        # Watches /photos for new images
│   └── show-error-image.sh    # Displays error image if slideshow fails
│   └── start-slideshow.sh     # Starts the slideshow
├── units/
│   ├── slideshow.service
│   ├── photos-watch.service
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
git clone https://github.com/yourusername/photo-frame-appliance.git
cd photo-frame-appliance
```

2. **Run the installer as root**:

```bash
sudo ./install.sh
```

The installer will:

* Install required packages: `fbi`, `psmisc`, `inotify-tools`
* Create `/photos`, `/boot/splash`, and `/usr/local/bin` directories as required
* Copy scripts and systemd service units
* Enable and start the slideshow, slideshow-error, and photo-watch services

---

## Adding Images

1. Place your images in `/photos`:

```bash
sudo cp ~/my-photos/*.jpg /photos/
sudo chmod 644 /photos/*.jpg
```

2. The slideshow will automatically start on boot, and **restart whenever new images are added** (30 seconds after the last file is added, to reduce disruptions if you're uploading a large batch of images at once).

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

**This will be reworked soon**

* All services run as user `jhandfield` in the `video` group by default
* Make sure the user exists and belongs to `video`:

```bash
sudo usermod -aG video jhandfield
```

* To change the username, edit all service files in `units/` before installation.

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

## License

This project is licensed under the MIT License. Feel free to fork and modify for personal projects or educational purposes.