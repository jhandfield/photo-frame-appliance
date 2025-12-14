#!/bin/sh

# Determine which error image to show based on time of day
HOUR=$(date +"%H")
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
  ERROR_IMAGE="/boot/splash/error-day.png"
else
  ERROR_IMAGE="/boot/splash/error-night.png"
fi

# Attempt to kill any processes using the framebuffer to avoid conflicts
fuser -k /dev/fb0 || true

# Display the error image using fbi
exec /usr/bin/fbi -noverbose -a "$ERROR_IMAGE"
