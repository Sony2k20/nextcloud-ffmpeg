# nextcloud-ffmpeg

Eigenes Nextcloud-Image mit `ffmpeg`, damit Nextcloud Vorschaubilder für Videos
erzeugen kann. Das offizielle Image bringt kein ffmpeg mit, der Preview-Provider
`OC\Preview\Movie` bleibt dort also wirkungslos.

Gebaut wird per GitHub Action, gepusht nach Docker Hub:
[`sony2k20/nextcloud-ffmpeg`](https://hub.docker.com/r/sony2k20/nextcloud-ffmpeg)

## Inhalt

| Datei | Zweck |
| --- | --- |
| `Dockerfile` | Basis-Image + ffmpeg, Version über Build-Arg `NEXTCLOUD_VERSION` |
| `.github/workflows/build-nextcloud-image.yml` | Build & Push, Version als Eingabe |

## Einmalige Einrichtung

1. Auf Docker Hub ein Personal Access Token mit Scope **Read & Write** erzeugen
   (Account Settings → Personal access tokens).
2. Im GitHub-Repo unter *Settings → Secrets and variables → Actions* anlegen:

   | Typ | Name | Wert |
   | --- | --- | --- |
   | Secret | `DOCKERHUB_USERNAME` | `sony2k20` |
   | Secret | `DOCKERHUB_TOKEN` | das Token aus Schritt 1 |
   | Variable | `NEXTCLOUD_VERSION` | z.B. `31-apache` (optional) |

Die Variable braucht nur der wöchentliche Cron-Lauf, der ohne manuelle Eingabe
startet. Das Docker-Hub-Repository muss nicht vorher existieren – beim ersten
Push wird es automatisch als *public* angelegt. Soll es privat sein, vorher auf
Docker Hub anlegen.

## Image bauen

*Actions → Build Nextcloud Image → Run workflow*

| Eingabe | Bedeutung | Default |
| --- | --- | --- |
| `nextcloud_version` | Tag des offiziellen Images, exakt wie auf Docker Hub | `31-apache` |
| `image_name` | Repository-Name unter `sony2k20/` | `nextcloud-ffmpeg` |
| `tag_latest` | zusätzlich `:latest` setzen | `true` |
| `platforms` | Zielarchitekturen | `linux/amd64` |
| `push` | pushen oder nur bauen (Testlauf) | `true` |

Gültige Werte für `nextcloud_version` sind alle Tags des offiziellen Images,
also z.B. `31-apache`, `31.0.5-apache`, `30-fpm`, `31-fpm-alpine`. Das
Dockerfile erkennt selbst, ob es sich um eine Debian- oder Alpine-Variante
handelt, und nutzt entsprechend `apt-get` oder `apk`.

`linux/arm64` wird auf dem Runner per QEMU emuliert. Das funktioniert, der
Paket-Installationsschritt dauert dabei aber ein Vielfaches – nur wählen, wenn
tatsächlich ARM-Nodes im Cluster stehen.

### Erzeugte Tags

Bei Eingabe `31.0.5-apache` entstehen:

```
sony2k20/nextcloud-ffmpeg:31.0.5-apache
sony2k20/nextcloud-ffmpeg:31.0.5-apache-20260817
sony2k20/nextcloud-ffmpeg:latest
```

Der Datums-Tag ist wichtig: Der wöchentliche Rebuild derselben Nextcloud-Version
überschreibt sonst den bestehenden Tag, und im Cluster lässt sich nicht mehr
feststellen, welches Build gerade läuft. Für produktive Deployments deshalb den
Datums-Tag pinnen, nicht `latest`.

### Lokal bauen

```bash
docker build --build-arg NEXTCLOUD_VERSION=31-apache -t nextcloud-ffmpeg:test .
docker run --rm --entrypoint /usr/bin/ffmpeg nextcloud-ffmpeg:test -version
```

## Verwendung im Helm-Chart

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

Sobald `enabledPreviewProviders` gesetzt ist, ersetzt die Liste die Defaults
komplett – alles eintragen, was aktiv sein soll.

Der Cron-Sidecar bzw. das Cron-CronJob des Charts nutzt automatisch dasselbe
Image und hat ffmpeg damit ebenfalls zur Verfügung. Das ist nötig, weil die App
*Preview Generator* (`occ preview:pre-generate`) dort läuft.

## Prüfen, ob es funktioniert

```bash
kubectl exec -it deploy/nextcloud -c nextcloud -- ffmpeg -version
kubectl exec -it deploy/nextcloud -c nextcloud -- \
  php occ config:system:get preview_ffmpeg_path
```

Wenn Vorschauen trotzdem fehlen: Nextcloud erzeugt sie standardmäßig erst beim
ersten Aufruf. Für bestehende Bestände die App *Preview Generator* installieren
und einmalig `occ preview:generate-all` laufen lassen – das kann bei vielen
Videos lange dauern und ordentlich CPU ziehen.

## Wartung

Der Workflow läuft montags um 04:00 UTC automatisch und baut die in der
Repository-Variable `NEXTCLOUD_VERSION` hinterlegte Version neu, damit
Security-Updates des Basis-Images und der Distribution ins Image kommen. Nach
einem Nextcloud-Upgrade die Variable auf die neue Version setzen.
