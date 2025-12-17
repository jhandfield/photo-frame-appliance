#!/bin/bash
# Start a slideshow of images in the /photos directory using fbi.

# Wait for photos to be available
while ! ls /photos/* >/dev/null 2>&1; do
  sleep 5
done

# Start fbi with all photos in /photos directory
exec /usr/bin/fbi -autozoom -noverbose -random -blend 1000 -timeout SLIDESHOW_INTERVAL /photos/*