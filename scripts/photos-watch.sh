#!/bin/sh
# Watch the /photos directory for changes to the photo collection and restart the slideshow service when changes are detected, with debouncing.

WATCH_DIR="PHOTO_DIR"
DEBOUNCE=30

while true; do
  inotifywait -e create -e moved_to -e moved_from -e delete "$WATCH_DIR" >/dev/null 2>&1

  while true; do
    inotifywait -t "$DEBOUNCE" -e create -e moved_to -e moved_from -e delete "$WATCH_DIR" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      break
    fi
  done

  logger -t photos-watch "New photo(s) detected; restarting slideshow.service"
  systemctl restart slideshow.service
done
