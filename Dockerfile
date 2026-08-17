# Wird von der GitHub Action per --build-arg gesetzt.
# Beispiele: 31-apache, 31.0.5-apache, 30-fpm, 31-fpm-alpine
ARG NEXTCLOUD_VERSION=31-apache
FROM nextcloud:${NEXTCLOUD_VERSION}

# Funktioniert sowohl fuer Debian- als auch fuer Alpine-basierte Tags.
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

# Nur zur Dokumentation im Image-Metadata - der Pfad, den Nextcloud braucht:
# 'preview_ffmpeg_path' => '/usr/bin/ffmpeg'
LABEL org.opencontainers.image.description="Nextcloud mit ffmpeg fuer Video-Previews"
