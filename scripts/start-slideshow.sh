#!/bin/bash
# Start a slideshow of images in the PHOTO_DIR directory using fbi.

# Wait for photos to be available
while ! ls PHOTO_DIR/* >/dev/null 2>&1; do
  sleep 5
done

# Start fbi with all photos in PHOTO_DIR directory
exec /usr/bin/fbi -autozoom -noverbose -random -blend 1000 -timeout SLIDESHOW_INTERVAL PHOTO_DIR/*