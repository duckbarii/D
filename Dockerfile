FROM nikolaik/python-nodejs:python3.10-nodejs19

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    aria2 \
    curl \
    wget \
    ca-certificates \
    jq \
 && curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
 && chmod a+rx /usr/local/bin/yt-dlp \
 && pip3 install --no-cache-dir yt-dlp \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy files into the container
COPY . .

# Make streamer.sh executable
RUN chmod +x streamer.sh

# Ensure videos dir exists
RUN mkdir -p videos

# Default command to start the streamer with RTMP URL
CMD ["bash", "streamer.sh"]