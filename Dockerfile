# Use the latest stable Ubuntu image
FROM ubuntu:22.04

# Set non-interactive mode to prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install dependencies in one layer to keep the image small
RUN apt-get update && apt-get install -y \
    apache2 \
    zip \
    unzip \
    openjdk-17-jr-headless \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download the template. 
# Using a GitHub mirror since direct downloads from template sites often fail with SSL/Link errors.
ADD https://github.com/themewagon/photogenic/archive/refs/heads/master.zip /var/www/html/photogenic.zip

# Set the working directory
WORKDIR /var/www/html/

# Unzip the file, move contents up, and clean up
RUN unzip photogenic.zip && \
    cp -rvf photogenic-master/* . && \
    rm -rf photogenic-master photogenic.zip index.html

# Expose Port 80 for web traffic
EXPOSE 80 22

# Start Apache in the foreground
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]