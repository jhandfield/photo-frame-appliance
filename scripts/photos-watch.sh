#!/bin/sh

WATCH_DIR="/photos"
DEBOUNCE=30

while true; do
  inotifywait -e create -e moved_to "$WATCH_DIR" >/dev/null 2>&1

  while true; do
    inotifywait -t "$DEBOUNCE" -e create -e moved_to "$WATCH_DIR" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      break
    fi
  done

  logger -t photos-watch "New photo(s) detected; restarting slideshow.service"
  systemctl restart slideshow.service
done
