# syntax=docker/dockerfile:1

# PHP images built on the official php ones (Debian), with Composer, WP-CLI,
# msmtp, Supercronic and a set of extensions that are enabled through the
# environment instead of a rebuild.
#
# Targets: cli, cli-dev, fpm, fpm-dev (the default). The -dev targets add
# Xdebug. PHP_VARIANT must match the target: fpm for fpm and fpm-dev, cli for
# cli and cli-dev.

ARG PHP_VERSION=8.4
ARG PHP_VARIANT=fpm
ARG DEBIAN_CODENAME=trixie
# CI passes the reference pinned to the digest it resolved, so the label below
# records exactly what the image was built from and the daily check in ci.yml
# can tell whether the official image has moved since.
ARG BASE_IMAGE=php:${PHP_VERSION}-${PHP_VARIANT}-${DEBIAN_CODENAME}

# Floating major tags on purpose: the weekly rebuild in ci.yml picks up their
# fixes without a commit.
FROM composer:2 AS composer
FROM mlocati/php-extension-installer:2 AS ipe

FROM ${BASE_IMAGE} AS base

ARG BASE_IMAGE
ARG TARGETARCH

# Enabled in every container.
ARG PHP_EXTENSIONS_CORE="bcmath exif gd intl mysqli opcache pdo_mysql zip"
# Compiled in, enabled through PHP_EXTENSIONS at container start.
ARG PHP_EXTENSIONS_OPTIONAL="apcu bz2 calendar ftp gettext gmp igbinary imagick ldap maxminddb memcached msgpack pcntl pdo_pgsql pgsql redis soap sockets tidy xsl"

# https://github.com/aptible/supercronic/releases
ARG SUPERCRONIC_VERSION=0.2.51
ARG SUPERCRONIC_SHA256_AMD64=cc232108374e8e2b537045f2d5eaa1229f619db314c3ba6a14d38b35dc0aa123
ARG SUPERCRONIC_SHA256_ARM64=4ae22576a78223d8ccdf5f3b3660a5cbb5288416bf0ca96afc4a36d195932b94

# https://github.com/wp-cli/wp-cli/releases. The profile command has to match
# it: profile-command 2.1.6 and later require wp-cli 2.13.
ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA512=be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832
ARG WP_CLI_PROFILE_VERSION=2.1.5

# Locales generated at build time, same syntax as the LOCALES variable. The
# only way to have extra locales in a rootless container.
ARG LOCALES=""

LABEL org.opencontainers.image.title="php" \
      org.opencontainers.image.description="Based on the official PHP images with Composer, WP-CLI, msmtp, Supercronic and extensions enabled through the environment" \
      org.opencontainers.image.source="https://github.com/xaas-hub/docker-php" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="${BASE_IMAGE}"

ENV WP_CLI_PACKAGES_DIR=/usr/local/share/wp-cli/packages

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# libfcgi-bin: cgi-fcgi for the FPM healthcheck.
# util-linux: setpriv, to drop privileges without gosu.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        less \
        libfcgi-bin \
        locales \
        msmtp \
        ncurses-bin \
        patch \
        tzdata \
        unzip \
        util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && command -v setpriv

COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY --from=ipe /usr/bin/install-php-extensions /usr/local/bin/

# Optional extensions are installed like the core ones, then their ini files
# are moved out of conf.d: docker-php-init loads the requested ones at start,
# in the order of their file names, which install-php-extensions chose so that
# igbinary and msgpack come before redis and memcached.
# hadolint ignore=SC2086
RUN install-php-extensions ${PHP_EXTENSIONS_CORE} ${PHP_EXTENSIONS_OPTIONAL} \
    && mkdir -p "${PHP_INI_DIR}/available" \
    && for ext in ${PHP_EXTENSIONS_OPTIONAL}; do \
        ini=("${PHP_INI_DIR}"/conf.d/*-php-ext-"${ext}".ini); \
        test -f "${ini[0]}" || { echo "no ini file for ${ext}" >&2; exit 1; }; \
        mv "${ini[0]}" "${PHP_INI_DIR}/available/"; \
    done

# The download URL takes the arch name Docker uses, but the checksum is pinned
# per arch: an unknown TARGETARCH fails here instead of shipping an unchecked
# binary.
RUN case "${TARGETARCH}" in \
        amd64) sha256="${SUPERCRONIC_SHA256_AMD64}" ;; \
        arm64) sha256="${SUPERCRONIC_SHA256_ARM64}" ;; \
        *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo /usr/local/bin/supercronic \
        "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" \
    && echo "${sha256}  /usr/local/bin/supercronic" | sha256sum -c - \
    && chmod +x /usr/local/bin/supercronic

# Packages go to WP_CLI_PACKAGES_DIR instead of root's home, so www-data finds
# them too. wp-cli's bundled Composer needs more than the 128M of
# php.ini-production to resolve the package.
# wp-cli registers the package as a GitHub VCS repository, which Composer
# resolves through the GitHub API: unauthenticated, the IPs shared by CI
# runners hit its rate limit. The token is optional, local builds work without.
# It goes in as http-basic with the x-oauth-basic password, which is how
# Composer stores github-oauth tokens internally: the github-oauth key itself
# is validated, and the Composer bundled in wp-cli rejects the dotted token
# format GitHub Actions issues.
RUN --mount=type=secret,id=github_token,required=false \
    curl -fsSLo /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && echo "${WP_CLI_SHA512}  /usr/local/bin/wp" | sha512sum -c - \
    && chmod +x /usr/local/bin/wp \
    && if [ -s /run/secrets/github_token ]; then \
        COMPOSER_AUTH="$(printf '{"http-basic":{"github.com":{"username":"%s","password":"x-oauth-basic"}}}' "$(cat /run/secrets/github_token)")"; \
        export COMPOSER_AUTH; \
    fi \
    && php -d memory_limit=512M /usr/local/bin/wp package install \
        "wp-cli/profile-command:${WP_CLI_PROFILE_VERSION}" --allow-root \
    && rm -rf /root/.wp-cli /root/.composer

COPY rootfs/ /

# - php.ini-production as the base: development settings belong in the
#   per-environment .user.ini files or in PHP_INI_* variables.
# - www-data gets a real home outside /var/www: usermod -u, run when USER_ID
#   is set, re-owns the whole home directory, which must not be the document
#   root on a bind mount.
# - /run/docker-php holds what docker-php-init generates. Sticky and world
#   writable, because a rootless container may run under any uid; the files
#   themselves are written root-owned and read-only whenever the container
#   starts as root. The links point there whether or not the targets exist
#   yet: PHP skips a dangling file in conf.d, and msmtp is only used once
#   MSMTP_HOST has generated its configuration.
RUN cp "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini" \
    && usermod -d /home/www-data www-data \
    && install -d -o www-data -g www-data -m 0755 /home/www-data \
    && install -d -m 1777 /run/docker-php /run/docker-php/fpm.d \
    && ln -s /run/docker-php/php.ini "${PHP_INI_DIR}/conf.d/zz-docker-php-runtime.ini" \
    && ln -sf /run/docker-php/msmtprc /etc/msmtprc \
    && install -d -m 0755 /docker-entrypoint.d \
    && if [ -n "${LOCALES}" ]; then docker-php-locales "${LOCALES}"; fi

ENTRYPOINT ["docker-php-init"]

FROM base AS cli

# Commands run as www-data: files written to bind mounts get the host user's
# ids once USER_ID and GROUP_ID are set. EXEC_USER= runs them as root.
ENV EXEC_USER=www-data

CMD ["php", "-a"]

FROM cli AS cli-dev

ENV XDEBUG_MODE=off

RUN install-php-extensions xdebug

FROM base AS fpm-base

# The master process stays root and the pool switches to www-data, so
# EXEC_USER stays empty here.
#
# The runtime pool file is included last, after zz-docker.conf. A missing match
# is only a warning for FPM.
RUN printf '\ninclude=/run/docker-php/fpm.d/*.conf\n' >>"${PHP_INI_DIR%/php}/php-fpm.conf" \
    && printf '%s\n' \
        '[www]' \
        'ping.path = /ping' \
        'access.suppress_path[] = /ping' \
        >"${PHP_INI_DIR%/php}/php-fpm.d/zzz-docker-php.conf"

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["php-fpm-healthcheck"]

CMD ["php-fpm"]

FROM fpm-base AS fpm-dev

ENV XDEBUG_MODE=off

RUN install-php-extensions xdebug

# Last stage: the default target.
FROM fpm-base AS fpm
