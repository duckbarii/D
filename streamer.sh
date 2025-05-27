#!/bin/bash

# --- Configuration ---
LINKS_FILE="links.txt"
COOKIES_FILE="cookies.txt"
VIDEO_DIR="videos"
# RTMP_URL will be read from the command line argument

# --- Script Logic ---

# Check if RTMP URL is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <RTMP_URL>"
    echo "Example: $0 rtmp://a.rtmp.youtube.com/live2/your_stream_key"
    exit 1
fi

RTMP_URL="$1"

# --- Check Prerequisites ---

# Check if links file exists
if [ ! -f "$LINKS_FILE" ]; then
    echo "Error: Links file not found: $LINKS_FILE"
    exit 1
fi

# Check if cookies file exists (optional but recommended if using cookies)
if [ ! -f "$COOKIES_FILE" ]; then
    echo "Warning: Cookies file not found: $COOKIES_FILE. Downloads might fail for restricted videos."
    # Do not exit, allow downloads of non-restricted videos
fi

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
    echo "Error: yt-dlp is not installed. Please install it (e.g., pip install yt-dlp)."
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it (e.g., sudo apt update && sudo apt install ffmpeg)."
    exit 1
fi

# --- Step 1: Read Links and Download ---

# Create the videos directory if it doesn't exist
mkdir -p "$VIDEO_DIR"

echo "Reading links..."

# Read links line by line and download
while IFS= read -r url || [ -n "$url" ]; do
    # Skip empty lines
    if [ -z "$url" ]; then
        continue
    fi

    echo "Downloading: $url"

    # Use yt-dlp to download the video
    # -f bestvideo+bestaudio: selects best quality video and audio streams
    # --merge-output-format mp4: merges them into an mp4 file
    # --cookies: specifies the cookies file
    # -o: output template for the filename
    # -q: quiet mode (less output during download)
    yt-dlp -f bestvideo+bestaudio --merge-output-format mp4 --cookies "$COOKIES_FILE" -o "$VIDEO_DIR/%(title)s.%(ext)s" -q "$url"

    # Check if download was successful (basic check based on yt-dlp's exit code)
    if [ $? -eq 0 ]; then
        echo "Download complete: $url"
    else
        echo "Warning: Download failed for: $url"
    fi

done < "$LINKS_FILE"

# --- Step 2: After All Downloads ---

echo "All videos downloaded. Starting stream."

# --- Step 3: Loop Streaming ---

# Check if there are any videos to stream
video_files=("$VIDEO_DIR"/*.mp4)
if [ "${#video_files[@]}" -eq 0 ] || [ ! -f "${video_files[0]}" ]; then
    echo "Error: No MP4 files found in '$VIDEO_DIR' to stream."
    exit 1
fi

# Infinite loop for streaming
while true; do
    echo "Starting a new streaming loop..."
    # Loop through all mp4 files in the videos directory
    # The `find` command is used to handle potential spaces or special characters in filenames robustly
    find "$VIDEO_DIR" -maxdepth 1 -type f -iname "*.mp4" -print0 | while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then # Double check if file exists (might be removed externally?)
            echo "Now streaming: $file"

            # Use ffmpeg to stream the video
            # -re: read input at native frame rate (important for streaming)
            # -i: input file
            # -c:v libx264: video codec (H.264)
            # -preset veryfast: encoding speed/quality trade-off (veryfast is good for streaming)
            # -c:a aac: audio codec (AAC)
            # -b:a 128k: audio bitrate
            # -f flv: output format (Flash Video, common for RTMP)
            # "$RTMP_URL": the destination RTMP server
            ffmpeg -re -i "$file" \
                   -c:v libx264 -preset veryfast \
                   -c:a aac -b:a 128k \
                   -f flv "$RTMP_URL"

            # Note: ffmpeg will block here until it finishes streaming the file or is interrupted.
            # If ffmpeg exits (e.g., error, stream interrupted), the script will move to the next file.

        else
            echo "Warning: File not found (or vanished during loop): $file. Skipping."
        fi
    done
    echo "Loop completed. Restarting."
done

exit 0 # This line will technically never be reached due to the infinite loop