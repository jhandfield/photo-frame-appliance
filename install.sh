#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "Installing dependencies..."
apt update
apt install -y fbi psmisc inotify-tools imagemagick

echo "Creating directories..."
mkdir -p /photos /boot/splash /usr/local/bin

echo "Setting photos directory permissions..."
chown -R $SUDO_USER:$SUDO_USER /photos
chmod g+sw /photos

echo "Copying scripts..."
cp scripts/photos-watch.sh /usr/local/bin/photos-watch.sh
cp scripts/show-error-image.sh /usr/local/bin/show-error-image.sh
cp scripts/start-slideshow.sh /usr/local/bin/start-slideshow.sh
cp scripts/photos-convert.sh /usr/local/bin/photos-convert.sh
chmod +x /usr/local/bin/photos-watch.sh /usr/local/bin/show-error-image.sh /usr/local/bin/start-slideshow.sh /usr/local/bin/photos-convert.sh

echo "Copying systemd unit files..."
cp units/*.service /etc/systemd/system/

echo "Copying splash and error images..."
# Copy default splash image if it exists
if [ -f splash/splash.png ]; then
  cp splash/splash.png /boot/splash/splash.png
  chmod 644 /boot/splash/splash.png
fi

# Copy error images if they exist
if [ -f splash/error-day.png ]; then
  cp splash/error-day.png /boot/splash/error-day.png
  chmod 644 /boot/splash/error-day.png
fi
if [ -f splash/error-night.png ]; then
  cp splash/error-night.png /boot/splash/error-night.png
  chmod 644 /boot/splash/error-night.png
fi

# Disable getty on tty1 to prevent interference with fbi
echo "Disabling getty on tty1..."
systemctl disable getty@tty1.service

# Locate the correct config.txt path
if [ -f /boot/firmware/config.txt ]; then
  CONFIG_TXT="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
  CONFIG_TXT="/boot/config.txt"
else
  CONFIG_TXT=""
fi

# Check if the console= we want is already present
if grep -q "^console=tty3 quiet loglevel=3 vt.global_cursor_default=0" "$CONFIG_TXT"; then
  echo "Console line found in config.txt; skipping modification."
  SKIP_CONSOLE_LINE=true
elif grep -q "^console=" "$CONFIG_TXT"; then
  if [ "$SKIP_CONSOLE_LINE" != "true" ]; then
    echo "Commenting existing console line..."
    sed -i 's|^console=.*|#&|' "$CONFIG_TXT"
  fi
fi

# Add console= line to config.txt if not skipped
if [ "$SKIP_CONSOLE_LINE" != "true" ]; then
  echo "Adding console line to config.txt..."
  echo "console=tty3 quiet loglevel=3 vt.global_cursor_default=0" >> "$CONFIG_TXT"
fi

# Enable and start services
echo "Enabling and starting services..."
systemctl daemon-reload
systemctl enable slideshow.service photos-watch.service photos-convert.service
systemctl start slideshow.service photos-watch.service photos-convert.service

# Add daily poweroff cron job at 22:00 local time
echo "Configuring daily poweroff at 22:00..."
POWEROFF_BIN="$(command -v poweroff || true)"
if [ -z "$POWEROFF_BIN" ]; then
  # Fallback paths commonly used
  if [ -x /sbin/poweroff ]; then
    POWEROFF_BIN="/sbin/poweroff"
  elif [ -x /usr/sbin/poweroff ]; then
    POWEROFF_BIN="/usr/sbin/poweroff"
  else
    echo "Warning: poweroff command not found; skipping cron setup."
  fi
fi

if [ -n "$POWEROFF_BIN" ]; then
  CRON_FILE="/etc/cron.d/photo-frame-poweroff"
  echo "Creating $CRON_FILE"
  printf "# Auto poweroff for photo-frame appliance\n" > "$CRON_FILE"
  printf "0 22 * * * root %s\n" "$POWEROFF_BIN" >> "$CRON_FILE"
  chmod 644 "$CRON_FILE"
fi

# Final message and reboot prompt
echo "Installation complete, rebooting is recommended. Reboot now? (y/N)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Please remember to reboot later to apply all changes."
fi