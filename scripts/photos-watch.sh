#!/bin/sh
# Watch the /photos directory for new images and restart slideshow.service when new images are added, optionally converting unsupported formats via ImageMagick.

WATCH_DIR="/photos"
DEBOUNCE=30

# Function to convert unsupported formats to JPEG
convert_unsupported_formats() {
  local converted=0
  
  # Convert HEIC files to JPEG - keep the original HEIC even though we won't show it, to allow us to use tools like rsync to sync external sources
  for file in "$WATCH_DIR"/*.heic "$WATCH_DIR"/*.HEIC; do
    if [ -f "$file" ]; then
      local base=$(basename "$file")
      local name="${base%.*}"
      local output="$WATCH_DIR/${name}.jpg"
      
      logger -t photos-watch "Converting HEIC file: $base"
      if convert "$file" "$output" 2>/dev/null; then
        logger -t photos-watch "Successfully converted $base to JPEG"
        converted=1
      else
        logger -t photos-watch "Failed to convert $base"
      fi
    fi
  done
  
  return $converted
}

while true; do
  inotifywait -e create -e moved_to "$WATCH_DIR" >/dev/null 2>&1

  while true; do
    inotifywait -t "$DEBOUNCE" -e create -e moved_to "$WATCH_DIR" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      break
    fi
  done

  # Convert any unsupported formats
  convert_unsupported_formats

  logger -t photos-watch "New photo(s) detected; restarting slideshow.service"
  systemctl restart slideshow.service
done
