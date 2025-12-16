#!/bin/sh
# Convert unsupported image formats to JPEG. Uses inotifywait to trigger on file events without debouncing.

WATCH_DIR="/photos"

# Function to convert a single HEIC file to JPEG
convert_heic_file() {
  local file="$1"
  
  if [ -f "$file" ]; then
    local base=$(basename "$file")
    local name="${base%.*}"
    # Keep the .HEIC in the output filename to avoid conflicts with unrelated images
    local output="$WATCH_DIR/${name}.HEIC.jpg"
    
    # Skip if output already exists
    if [ ! -f "$output" ]; then
      logger -t photos-convert "Converting HEIC file: $base"
      if convert "$file" "$output" 2>/dev/null; then
        logger -t photos-convert "Successfully converted $base to JPEG"
      else
        logger -t photos-convert "Failed to convert $base"
      fi
    fi
  fi
}

# Convert any existing HEIC files on startup
logger -t photos-convert "Scanning for existing HEIC files..."
for file in "$WATCH_DIR"/*.heic "$WATCH_DIR"/*.HEIC; do
  convert_heic_file "$file"
done

# Watch for new HEIC files
logger -t photos-convert "Monitoring $WATCH_DIR for new HEIC files..."
while inotifywait -e create -e moved_to "$WATCH_DIR" 2>/dev/null; do
  # Convert any new HEIC files
  for file in "$WATCH_DIR"/*.heic "$WATCH_DIR"/*.HEIC; do
    convert_heic_file "$file"
  done
done
