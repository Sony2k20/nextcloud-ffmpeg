# nextcloud-ffmpeg

Custom Nextcloud image with `ffmpeg`, so Nextcloud can generate video
thumbnails. The official image doesn't ship ffmpeg, so the preview provider
`OC\Preview\Movie` stays non-functional there.

Built via GitHub Action, pushed to Docker Hub:
[`sony2k20/nextcloud-ffmpeg`](https://hub.docker.com/r/sony2k20/nextcloud-ffmpeg)

## Contents

| File | Purpose |
| --- | --- |
| `Dockerfile` | Base image + ffmpeg, version via build arg `NEXTCLOUD_VERSION` |
| `.github/workflows/build-nextcloud-image.yml` | Build & push, version as input |

## One-time setup

1. On Docker Hub, create a Personal Access Token with scope **Read & Write**
   (Account Settings → Personal access tokens).
2. In the GitHub repo under *Settings → Secrets and variables → Actions*, add:

   | Type | Name | Value |
   | --- | --- | --- |
   | Secret | `DOCKERHUB_USERNAME` | `sony2k20` |
   | Secret | `DOCKERHUB_TOKEN` | the token from step 1 |
   | Variable | `NEXTCLOUD_VERSION` | e.g. `31-apache` (optional) |

The variable is only needed for the weekly cron run, which starts without
manual input. The Docker Hub repository doesn't need to exist beforehand –
it's created automatically as *public* on the first push. If it should be
private, create it on Docker Hub first.

## Building the image

*Actions → Build Nextcloud Image → Run workflow*

| Input | Meaning | Default |
| --- | --- | --- |
| `nextcloud_version` | Tag of the official image, exactly as on Docker Hub | `31-apache` |
| `image_name` | Repository name under `sony2k20/` | `nextcloud-ffmpeg` |
| `tag_latest` | also set `:latest` | `true` |
| `platforms` | Target architectures | `linux/amd64` |
| `push` | push or build only (test run) | `true` |

Valid values for `nextcloud_version` are all tags of the official image,
e.g. `31-apache`, `31.0.5-apache`, `30-fpm`, `31-fpm-alpine`. The Dockerfile
automatically detects whether it's a Debian- or Alpine-based variant and uses
`apt-get` or `apk` accordingly.

`linux/arm64` is emulated on the runner via QEMU. This works, but the package
installation step then takes several times longer – only choose it if there
are actually ARM nodes in the cluster.

### Generated tags

Given the input `31.0.5-apache`, the following are created:

```
sony2k20/nextcloud-ffmpeg:31.0.5-apache
sony2k20/nextcloud-ffmpeg:31.0.5-apache-20260817
sony2k20/nextcloud-ffmpeg:latest
```

The date tag matters: the weekly rebuild of the same Nextcloud version would
otherwise overwrite the existing tag, and in the cluster it would no longer be
possible to tell which build is currently running. For production deployments,
pin the date tag rather than `latest`.

### Building locally

```bash
docker build --build-arg NEXTCLOUD_VERSION=31-apache -t nextcloud-ffmpeg:test .
docker run --rm --entrypoint /usr/bin/ffmpeg nextcloud-ffmpeg:test -version
```

## Usage in the Helm chart

```yaml
image:
  repository: sony2k20/nextcloud-ffmpeg
  tag: "31.0.5-apache-20260817"
  pullPolicy: IfNotPresent

nextcloud:
  configs:
    previews.config.php: |-
      <?php
      $CONFIG = array(
        'enable_previews' => true,
        'enabledPreviewProviders' => array(
          'OC\Preview\Image',
          'OC\Preview\HEIC',
          'OC\Preview\TXT',
          'OC\Preview\MarkDown',
          'OC\Preview\PDF',
          'OC\Preview\Movie',
        ),
        'preview_ffmpeg_path' => '/usr/bin/ffmpeg',
        'preview_max_x' => 2048,
        'preview_max_y' => 2048,
      );
```

As soon as `enabledPreviewProviders` is set, this list completely replaces
the defaults – add everything that should be active.

The chart's cron sidecar/CronJob automatically uses the same image and thus
also has ffmpeg available. This is needed because the *Preview Generator* app
(`occ preview:pre-generate`) runs there.

## Checking that it works

```bash
kubectl exec -it deploy/nextcloud -c nextcloud -- ffmpeg -version
kubectl exec -it deploy/nextcloud -c nextcloud -- \
  php occ config:system:get preview_ffmpeg_path
```

If previews are still missing: by default, Nextcloud only generates them on
first access. For existing content, install the *Preview Generator* app and
run `occ preview:generate-all` once – this can take a long time and use a lot
of CPU for many videos.

## Maintenance

The workflow runs automatically every Monday at 04:00 UTC and rebuilds the
version stored in the repository variable `NEXTCLOUD_VERSION`, so that
security updates of the base image and distribution make it into the image.
After a Nextcloud upgrade, set the variable to the new version.
