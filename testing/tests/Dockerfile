# Use Ubuntu 24.04 as base image
FROM ubuntu:24.04

# Set environment variable to avoid interactive dialogues during build
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary APT packages including Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-venv \
    python3-pip \
    zip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Set timezone (optional)
ENV TZ=America/New_York

# Keep the container running (This can be replaced by your application's main process)
CMD ["tail", "-f", "/dev/null"]
