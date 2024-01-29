# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variable to avoid interactive dialogues during build
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary APT packages including Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-venv \
    python3-pip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Creating a virtual environment in /app/venv
RUN python3 -m venv /app/venv

# Activate the virtual environment
ENV PATH="/app/venv/bin:$PATH"

# Copy requirements.txt to the container
COPY requirements.txt .

# Install Python dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Set timezone (optional)
ENV TZ=America/New_York

# Keep the container running (This can be replaced by your application's main process)
CMD ["tail", "-f", "/dev/null"]
