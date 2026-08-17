# Set by the GitHub Action via --build-arg.
# Examples: 31-apache, 31.0.5-apache, 30-fpm, 31-fpm-alpine
ARG NEXTCLOUD_VERSION=31-apache
FROM nextcloud:${NEXTCLOUD_VERSION}

# Works for both Debian- and Alpine-based tags.
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache ffmpeg; \
    else \
        apt-get update; \
        apt-get install -y --no-install-recommends ffmpeg; \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    ffmpeg -version; \
    ffprobe -version

# For documentation in the image metadata only - the path Nextcloud needs:
# 'preview_ffmpeg_path' => '/usr/bin/ffmpeg'
LABEL org.opencontainers.image.description="Nextcloud with ffmpeg for video previews"
