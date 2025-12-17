#!/bin/bash
set -e

#########################################
# DEFAULT CONFIGURATION
# Override by creating config.sh in the same directory
#########################################
# User and group to run services as
RUN_USER="$SUDO_USER"
RUN_GROUP="$SUDO_USER"

# Compute the default photos directory under the RUN_USER's home
USER_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ]; then
  USER_HOME="$(eval echo ~"$RUN_USER" 2>/dev/null || echo "/home/$RUN_USER")"
fi
PHOTOS_DIR="$USER_HOME/Pictures"
SPLASH_DIR="/boot/splash"
SLIDESHOW_INTERVAL=300  # Seconds to display each photo (default: 300 = 5 minutes)

AUTO_POWEROFF_ENABLED=true
AUTO_POWEROFF_TIME="22:00"  # 24-hour format HH:MM

# Load optional configuration overrides
if [ -f "$(dirname "$0")/config.sh" ]; then
  echo "Loading configuration from config.sh..."
  source "$(dirname "$0")/config.sh"
fi
#########################################

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "Configuration:"
echo "  Photos directory: $PHOTOS_DIR"
echo "  Splash directory: $SPLASH_DIR"
echo "  Run as user: $RUN_USER"
echo "  Run as group: $RUN_GROUP"
echo "  Slideshow interval: $SLIDESHOW_INTERVAL seconds"
echo "  Auto-poweroff: $AUTO_POWEROFF_ENABLED"
if [ "$AUTO_POWEROFF_ENABLED" = "true" ]; then
  echo "  Poweroff time: $AUTO_POWEROFF_TIME"
fi
echo ""

echo "Installing dependencies..."
apt update
apt install -y fbi psmisc inotify-tools imagemagick

echo "Creating directories..."
mkdir -p "$PHOTOS_DIR" "$SPLASH_DIR" /usr/local/bin

echo "Setting photos directory permissions..."
chown -R "$RUN_USER:$RUN_GROUP" "$PHOTOS_DIR"
chmod g+sw "$PHOTOS_DIR"

echo "Copying scripts..."
cp scripts/photos-watch.sh /usr/local/bin/photos-watch.sh
cp scripts/show-error-image.sh /usr/local/bin/show-error-image.sh
cp scripts/photos-convert.sh /usr/local/bin/photos-convert.sh
# Substitute SLIDESHOW_INTERVAL and PHOTOS_DIR in start-slideshow.sh
sed -e "s/SLIDESHOW_INTERVAL/$SLIDESHOW_INTERVAL/g" -e "s|/photos|$PHOTOS_DIR|g" scripts/start-slideshow.sh > /usr/local/bin/start-slideshow.sh
chmod +x /usr/local/bin/photos-watch.sh /usr/local/bin/show-error-image.sh /usr/local/bin/start-slideshow.sh /usr/local/bin/photos-convert.sh

echo "Copying systemd unit files..."
# Substitute configuration variables in service files
for service_file in units/*.service; do
  service_name=$(basename "$service_file")
  sed -e "s|/photos|$PHOTOS_DIR|g" \
      -e "s|User=.*|User=$RUN_USER|g" \
      -e "s|Group=.*|Group=$RUN_GROUP|g" \
      "$service_file" > "/etc/systemd/system/$service_name"
done

echo "Copying splash and error images..."
# Copy default splash image if it exists
if [ -f splash/splash.png ]; then
  cp splash/splash.png "$SPLASH_DIR/splash.png"
  chmod 644 "$SPLASH_DIR/splash.png"
fi

# Copy error images if they exist
if [ -f splash/error-day.png ]; then
  cp splash/error-day.png "$SPLASH_DIR/error-day.png"
  chmod 644 "$SPLASH_DIR/error-day.png"
fi
if [ -f splash/error-night.png ]; then
  cp splash/error-night.png "$SPLASH_DIR/error-night.png"
  chmod 644 "$SPLASH_DIR/error-night.png"
fi

# Disable getty on tty1 to prevent interference with fbi
echo "Disabling getty on tty1..."
systemctl disable getty@tty1.service

# Locate the correct config.txt path and boot partition
if [ -f /boot/firmware/config.txt ]; then
  CONFIG_TXT="/boot/firmware/config.txt"
  BOOT_PARTITION="/boot/firmware"
elif [ -f /boot/config.txt ]; then
  CONFIG_TXT="/boot/config.txt"
  BOOT_PARTITION="/boot"
else
  CONFIG_TXT=""
  BOOT_PARTITION=""
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
systemctl enable slideshow.service photos-watch.service photos-convert.service boot-splash.service
systemctl start slideshow.service photos-watch.service photos-convert.service

# Configure daily poweroff if enabled
if [ "$AUTO_POWEROFF_ENABLED" = "true" ]; then
  echo "Configuring daily poweroff at $AUTO_POWEROFF_TIME..."
  POWEROFF_BIN="$(command -v poweroff || true)"
  if [ -z "$POWEROFF_BIN" ]; then
    # Fallback paths commonly used
    if [ -x /sbin/poweroff ]; then
      POWEROFF_BIN="/sbin/poweroff"
    elif [ -x /usr/sbin/poweroff ]; then
      POWEROFF_BIN="/usr/sbin/poweroff"
    else
      echo "Warning: poweroff command not found; skipping cron setup." >&2
      POWEROFF_BIN=""
    fi
  fi

  if [ -n "$POWEROFF_BIN" ]; then
    # Parse time (HH:MM format)
    HOUR="${AUTO_POWEROFF_TIME%%:*}"
    MINUTE="${AUTO_POWEROFF_TIME##*:}"
    
    # Validate time format
    if ! [[ "$HOUR" =~ ^[0-9]{1,2}$ ]] || ! [[ "$MINUTE" =~ ^[0-9]{1,2}$ ]] || \
       [ "$HOUR" -gt 23 ] || [ "$MINUTE" -gt 59 ]; then
      echo "Error: Invalid time format '$AUTO_POWEROFF_TIME'. Use HH:MM (e.g., 22:00)" >&2
      echo "Skipping cron setup." >&2
    else
      CRON_FILE="/etc/cron.d/photo-frame-poweroff"
      tmpfile="$(mktemp)"
      cat >"$tmpfile" <<EOF
SHELL=/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Auto poweroff for photo-frame appliance at $AUTO_POWEROFF_TIME
$MINUTE $HOUR * * * root $POWEROFF_BIN
EOF
      install -m 0644 -o root -g root "$tmpfile" "$CRON_FILE"
      rm -f "$tmpfile"
      echo "Installed cron job: $CRON_FILE"
    fi
  fi
else
  echo "Auto-poweroff disabled; skipping cron setup."
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