[![Docker Pulls](https://img.shields.io/docker/pulls/frugan/php)](https://hub.docker.com/r/frugan/php)
[![Build Status](https://github.com/xaas-hub/docker-php/actions/workflows/ci.yml/badge.svg)](https://github.com/xaas-hub/docker-php/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/xaas-hub/docker-php)](https://github.com/xaas-hub/docker-php/releases)
[![License](https://img.shields.io/github/license/xaas-hub/docker-php)](https://github.com/xaas-hub/docker-php/blob/main/LICENSE)

# PHP

The [official PHP images](https://hub.docker.com/_/php) (Debian), plus what
WordPress and Laravel sites need around them: Composer, WP-CLI with the
`profile` command, msmtp for `mail()`, Supercronic, extra locales, and a set
of extensions you switch on with an environment variable instead of a
rebuild.

The official images are the base on purpose: they get a PHP security release
within hours, and a daily job here rebuilds as soon as their digest moves.

---

## What is in the image

|                                                                  |                                                                    |
| ---------------------------------------------------------------- | ------------------------------------------------------------------ |
| [Composer](https://getcomposer.org) 2                            | `composer`                                                         |
| [WP-CLI](https://wp-cli.org)                                     | `wp`, with [`wp profile`](https://developer.wordpress.org/cli/commands/profile/) preinstalled |
| [msmtp](https://marlam.de/msmtp/)                                | `sendmail_path`, configured from `MSMTP_*`                         |
| [Supercronic](https://github.com/aptible/supercronic)            | cron for containers                                                |
| [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer) | for images built `FROM` this one                |
| git, unzip, patch, less, curl, tzdata, locales                   | what Composer and WP-CLI expect to find                            |

Extensions always enabled: bcmath, exif, gd, intl, mysqli, opcache,
pdo_mysql, sodium, zip, plus those of the official image.

Optional, enabled with `PHP_EXTENSIONS`: apcu, igbinary, imagick, memcached,
msgpack, pdo_pgsql, pgsql, redis, soap. The `-dev` images add Xdebug, loaded with
`XDEBUG_MODE=off`.

`php.ini` is `php.ini-production`, with `expose_php = Off`.

## Available tags

The same images, with the same tags, are published to two registries: use
either.

| Registry        | Image                                                                                       |
| --------------- | ------------------------------------------------------------------------------------------- |
| Docker Hub      | [`frugan/php`](https://hub.docker.com/r/frugan/php)                                         |
| GitHub Packages | [`ghcr.io/xaas-hub/php`](https://github.com/orgs/xaas-hub/packages/container/package/php) |

```text
frugan/php:<php>-<variant>[-dev][-v<release>]
ghcr.io/xaas-hub/php:<same>
```

| Tag                | Content                                                       |
| ------------------ | ------------------------------------------------------------- |
| `8.4-fpm`          | latest PHP 8.4, latest release of this image: updated daily   |
| `8.4.27-fpm`       | that PHP release, rebuilt until the next one replaces it      |
| `8.4-fpm-v1.2.3`   | the image as of release 1.2.3, never rebuilt                  |
| `8.4-fpm-dev`      | the same three forms, with Xdebug                             |

PHP: `8.2`, `8.3`, `8.4`, `8.5` (the branches PHP supports). Variants:
`fpm`, `cli`. Platforms: `linux/amd64`, `linux/arm64`. There is no `latest`:
pick a PHP branch.

The rolling tags are the ones to run: a new PHP patch release or Debian
security update reaches them within a day, without any change on your side.
The `-v` tags are for reproducing a build exactly, and they go stale.

## Quick start

```yaml
services:
  php:
    image: frugan/php:8.4-fpm
    init: true
    environment:
      APP_ENV: production
      USER_ID: 1000          # your uid on the host: files written by PHP are yours
      GROUP_ID: 1000
      PHP_EXTENSIONS: apcu,imagick,redis
      PHP_INI_MEMORY_LIMIT: 256M
      PHP_INI_UPLOAD_MAX_FILESIZE: 64M
      PHP_INI_POST_MAX_SIZE: 64M
      FPM_POOL_PM__MAX_CHILDREN: 20
      MSMTP_HOST: smtp.example.com
      MSMTP_USER: noreply@example.com
      MSMTP_PASSWORD_FILE: /run/secrets/smtp_password
    secrets:
      - smtp_password
    volumes:
      - ./html:/var/www/html

secrets:
  smtp_password:
    file: ./secrets/smtp_password
```

FPM listens on port 9000, like the official image: point nginx, Caddy or
Traefik there.

Commands inside a running container:

```bash
docker compose exec -u www-data php wp plugin list
docker compose exec -u www-data php composer install
```

`-u www-data` matters: `docker exec` does not go through the entry point and
runs as root otherwise.

## Configuration

Everything is read at container start: change the environment and recreate
the container.

### Extensions

| Variable         | Default |                                                        |
| ---------------- | ------- | ------------------------------------------------------ |
| `PHP_EXTENSIONS` |         | optional extensions, separated by commas or spaces     |

`redis` and `memcached` bring `igbinary` and `msgpack` with them: they are
compiled against both. An extension that is not in the image stops the
container with the list of the available ones. For anything else, build on
top of this image:

```dockerfile
FROM frugan/php:8.4-fpm
RUN install-php-extensions mongodb
```

#### libvips

libvips is not in the image, and is better kept away from FPM.
[intervention/image-driver-vips](https://github.com/Intervention/image-driver-vips)
reaches it through [php-vips](https://github.com/libvips/php-vips), which
calls libvips over FFI. By default PHP allows FFI only in the CLI and in
preloaded code (`ffi.enable=preload`): allowing it in FPM (`ffi.enable=true`)
would let any PHP code of the site call C functions, past `disable_functions`
and `open_basedir`.

For most sites `PHP_EXTENSIONS=imagick` and the Imagick driver of Intervention
Image are enough. When libvips pays off (large images, high volumes), process
the images in queued jobs, Laravel queues for instance, run by a worker built
from the cli image, where FFI works with the default settings, and leave FPM
as it is:

```dockerfile
FROM frugan/php:8.4-cli
RUN apt-get update \
    && apt-get install -y --no-install-recommends libvips42t64 \
    && rm -rf /var/lib/apt/lists/*
```

### php.ini and FPM pool

| Variable          |                                                               |
| ----------------- | ------------------------------------------------------------- |
| `PHP_INI_<NAME>`  | any php.ini directive                                         |
| `FPM_POOL_<NAME>` | any directive of the `www` pool (fpm images)                  |

`<NAME>` is the directive in upper case, with `__` for the dot:

```text
PHP_INI_MEMORY_LIMIT=256M                 memory_limit = "256M"
PHP_INI_OPCACHE__JIT_BUFFER_SIZE=64M      opcache.jit_buffer_size = "64M"
PHP_INI_DATE__TIMEZONE=Europe/Rome        date.timezone = "Europe/Rome"
FPM_POOL_PM=static                        pm = "static"
FPM_POOL_PM__MAX_CHILDREN=20              pm.max_children = "20"
```

Values may not contain double quotes or newlines. `PHP_INI_DIR` and
`PHP_INI_SCAN_DIR` belong to the official image and are not directives. Array
directives such as `php_admin_value[...]` have no variable form: mount a
file in `/usr/local/etc/php-fpm.d/` or `/usr/local/etc/php/conf.d/`.

A `PHP_INI_*` or `FPM_POOL_*` variable set to an empty value is written too,
as `directive = ""`: that is how a directive is cleared
(`PHP_INI_DISABLE_FUNCTIONS=`). In a compose file, `${MEMORY_LIMIT}` left
unset therefore clears `memory_limit` instead of keeping the default: write
`${MEMORY_LIMIT:-128M}`.

### Environments and .user.ini

| Variable  | Default      |                                                     |
| --------- | ------------ | --------------------------------------------------- |
| `APP_ENV` | `production` | `production`, `staging`, `develop`, anything else   |

In production PHP reads the standard `.user.ini` (cached for 300 seconds). In
any other environment it reads `.user-<APP_ENV>.ini` instead, with
`user_ini.cache_ttl = 0` so that edits apply on the next request; set
`PHP_INI_USER_INI__CACHE_TTL` for another value. Keep the development
settings (`display_errors`, `error_reporting`...) in `.user-develop.ini` next
to the `.user.ini` of production.

The image never sets `APP_ENV` in the environment itself: Laravel's `.env`
keeps working when the variable is not passed. When it is, FPM hands it to the
workers like every other variable (`clear_env = no`, as in the official
image).

### Users and permissions

| Variable              | Default                     |                                       |
| --------------------- | --------------------------- | ------------------------------------- |
| `USER_ID`, `GROUP_ID` |                             | ids www-data takes at start           |
| `EXEC_USER`           | `www-data` (cli), empty (fpm) | user the command runs as            |

**Default: remapping.** The container starts as root, gives `www-data` the
ids in `USER_ID` and `GROUP_ID`, and FPM runs its workers as `www-data`: what
PHP writes on a bind mount belongs to your user on the host. The cli images
also run their command as `www-data`; `EXEC_USER=` runs it as root.

**Alternative: rootless.** Start the container with `user: "1000:1000"` (or
`--user`): nothing runs as root, the ids are the container's own, and
`USER_ID`, `GROUP_ID`, `EXEC_USER` and `LOCALES` are ignored. Everything else
works the same. With `read_only: true`, give it a writable `/run/docker-php`:

```yaml
    user: "1000:1000"
    read_only: true
    tmpfs:
      - /run/docker-php
      - /tmp
```

### Mail (msmtp)

| Variable              | Default         |                                                   |
| --------------------- | --------------- | ------------------------------------------------- |
| `MSMTP_HOST`          |                 | SMTP server; nothing is generated without it      |
| `MSMTP_PORT`          | `587`           |                                                   |
| `MSMTP_TLS`           | `starttls`      | `starttls`, `on` (implicit, default on port 465), `off` |
| `MSMTP_TLS_CERTCHECK` | `on`            |                                                   |
| `MSMTP_USER`          |                 | enables authentication                            |
| `MSMTP_PASSWORD_FILE` |                 | file holding the password, e.g. a Docker secret   |
| `MSMTP_PASSWORD`      |                 | the password itself, when a file is not an option |
| `MSMTP_FROM`          |                 | envelope sender, when PHP does not pass one       |
| `MSMTP_LOGFILE`       |                 | `-` logs every message to the container output    |

`sendmail_path` is `/usr/bin/msmtp -t`, which reads `/etc/msmtprc`. The
generated file is readable by root and `www-data` only, and `MSMTP_PASSWORD`
is removed from the environment before PHP starts. Without `MSMTP_HOST`,
mount your own configuration on `/etc/msmtprc` instead.

### Cron (Supercronic)

| Variable              | Default        |                                          |
| --------------------- | -------------- | ---------------------------------------- |
| `SUPERCRONIC_ENABLED` |                | start Supercronic next to the command    |
| `SUPERCRONIC_CRONTAB` | `/etc/crontab` |                                          |
| `SUPERCRONIC_FLAGS`   |                | e.g. `-json`, `-split-logs`, `-overlapping` |

Jobs run as `www-data`. With `SUPERCRONIC_ENABLED` it runs in the background
of the FPM container, and nothing restarts it if it dies: add `init: true`.
The cleaner setup is a separate container from the cli image, which Docker
restarts on its own:

```yaml
  cron:
    image: frugan/php:8.4-cli
    init: true
    restart: unless-stopped
    command: ["supercronic", "/etc/crontab"]
    environment:
      USER_ID: 1000
      GROUP_ID: 1000
    volumes:
      - ./html:/var/www/html
      - ./crontab:/etc/crontab:ro
```

### Locales

| Variable  |                                                                  |
| --------- | ---------------------------------------------------------------- |
| `LOCALES` | `it_IT.UTF-8, de_DE.UTF-8`, full lines such as `en_US ISO-8859-1`, or `all` |

Generated at start, only when the list changes (about a second each; `all`
takes minutes). Rootless containers cannot generate them: build them in with
`--build-arg LOCALES="it_IT.UTF-8"`.

### Hooks

Files `/docker-entrypoint.d/*.sh` are sourced in order after the steps above
and before the command, as root unless the container is rootless. They can
export variables for the command.

### Healthcheck

The fpm images ship a `HEALTHCHECK` that asks the pool for `/ping` over
FastCGI, at the address in `FPM_POOL_LISTEN` (9000 by default). The ping
requests are left out of the access log.

## Building

```bash
docker build --build-arg PHP_VERSION=8.3 --build-arg PHP_VARIANT=cli \
  --target cli-dev -t php:8.3-cli-dev .
```

| Argument                  | Default                                  |
| ------------------------- | ---------------------------------------- |
| `PHP_VERSION`             | `8.4`                                    |
| `PHP_VARIANT`             | `fpm`; must match the target             |
| `BASE_IMAGE`              | `php:<PHP_VERSION>-<PHP_VARIANT>-trixie` |
| `PHP_EXTENSIONS_CORE`     | the always enabled extensions            |
| `PHP_EXTENSIONS_OPTIONAL` | the ones `PHP_EXTENSIONS` enables        |
| `LOCALES`                 | locales generated at build time          |

Targets: `fpm` (default), `fpm-dev`, `cli`, `cli-dev`. The end-to-end test
runs against any of them:

```bash
tests/smoke.sh php:8.3-cli-dev cli-dev
```

## Release and publishing

Every merge to `main` goes through semantic-release: the commit types decide
the version (see [CONTRIBUTING](.github/CONTRIBUTING.md)), and the release
publishes all images with their `-v` tags and refreshes the rolling ones.

Rolling tags only ever carry released code. Every day the official base
images are checked: the images whose base moved are rebuilt from the latest
release, tested and republished. Once a week everything is rebuilt anyway,
for Composer, install-php-extensions and the PECL extensions. Each
architecture builds on a native runner, then the two are joined into one tag.

## Contributing

For your contributions please use:

- [Conventional Commits](https://www.conventionalcommits.org)
- [Pull request workflow](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project)

See [CONTRIBUTING](.github/CONTRIBUTING.md) for detailed guidelines.

## Sponsor

[<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="200" alt="Buy Me A Coffee">](https://buymeacoff.ee/frugan)

## License

Copyright (c) 2026 [Frugan](https://frugan.it). [MIT](https://choosealicense.com/licenses/mit/),
see the [LICENSE](LICENSE) file.

PHP, Composer, WP-CLI, msmtp, Supercronic and the bundled extensions keep
their own licenses.
