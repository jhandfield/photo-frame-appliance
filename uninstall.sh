#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--remove-apt-packages]"
  echo "  --remove-apt-packages  Purge fbi, psmisc, inotify-tools, imagemagick and autoremove dependencies"
  exit 1
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

REMOVE_APT_PACKAGES=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-apt-packages)
      REMOVE_APT_PACKAGES=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

services=(slideshow.service photos-watch.service photos-convert.service slideshow-error.service)
scripts=(/usr/local/bin/photos-watch.sh /usr/local/bin/show-error-image.sh /usr/local/bin/slideshow.sh)
images=(/boot/splash/splash.png /boot/splash/error-day.png /boot/splash/error-night.png)
unit_dir=/etc/systemd/system
dirs_to_clean=(/boot/splash /photos)

echo "Stopping services..."
for srv in "${services[@]}"; do
  if systemctl is-active --quiet "$srv"; then
    systemctl stop "$srv"
  fi
done

echo "Disabling services..."
for srv in "${services[@]}"; do
  if systemctl is-enabled --quiet "$srv"; then
    systemctl disable "$srv"
  fi
done

echo "Removing systemd unit files..."
for srv in "${services[@]}"; do
  unit_path="$unit_dir/$srv"
  if [ -f "$unit_path" ]; then
    rm -f "$unit_path"
  fi
done

# Re-enable getty on tty1
echo "Re-enabling getty on tty1..."
systemctl enable getty@tty1.service

# Locate the correct config.txt path
if [ -f /boot/firmware/config.txt ]; then
  CONFIG_TXT="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
  CONFIG_TXT="/boot/config.txt"
else
  CONFIG_TXT=""
fi

# Remove the console line we added during install
sed -i 's|^console=tty3 quiet loglevel=3 vt.global_cursor_default=0||' "$CONFIG_TXT"

# Uncomment any previously commented console= lines
sed -i 's|^#console=.*|console=&|' "$CONFIG_TXT"

# Reload systemd daemon to apply changes
systemctl daemon-reload

# Remove daily poweroff cron job
echo "Removing poweroff cron job..."
CRON_FILE="/etc/cron.d/photo-frame-poweroff"
if [ -f "$CRON_FILE" ]; then
  rm -f "$CRON_FILE"
fi

echo "Removing scripts..."
for script_path in "${scripts[@]}"; do
  if [ -f "$script_path" ]; then
    rm -f "$script_path"
  fi
done

echo "Removing splash/error images..."
for img in "${images[@]}"; do
  if [ -f "$img" ]; then
    rm -f "$img"
  fi
done

echo "Cleaning empty directories..."
for dir in "${dirs_to_clean[@]}"; do
  if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ]; then
    rmdir "$dir"
  fi
done

if $REMOVE_APT_PACKAGES; then
  echo "Removing apt packages and dependencies..."
  apt remove --purge -y fbi psmisc inotify-tools imagemagick
  apt autoremove --purge -y
else
  echo "Leaving apt packages installed. Re-run with --remove-apt-packages to purge them."
fi

echo "Uninstall complete. User content (if any) was preserved. Rebooting is recommended; reboot now? (y/N)"

read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Please remember to reboot later to apply all changes."
fi