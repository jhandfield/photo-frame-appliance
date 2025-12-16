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
chmod +x /usr/local/bin/photos-watch.sh /usr/local/bin/show-error-image.sh /usr/local/bin/start-slideshow.sh

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

# Enable and start services
echo "Enabling and starting services..."
systemctl daemon-reload
systemctl enable slideshow.service photos-watch.service slideshow-error.service
systemctl start slideshow.service photos-watch.service

echo "Installation complete."
echo "Add images to /photos and reboot to test."
