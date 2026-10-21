# Contributing to docker-php

Thank you for your interest in contributing!

## Repository Structure

```text
├── Dockerfile                  # Targets cli, cli-dev, fpm, fpm-dev on the official php images
├── rootfs/                     # Copied as is into the image
│   └── usr/local/
│       ├── bin/
│       │   ├── docker-php-init         # Entry point: runs init.d/, the hooks, then the command
│       │   ├── docker-php-locales      # Locale generation, also used at build time
│       │   └── php-fpm-healthcheck     # FastCGI ping of the pool
│       ├── lib/docker-php/
│       │   ├── common.sh               # Helpers shared by the steps
│       │   └── init.d/                 # One step per feature, sourced in order
│       └── etc/php/conf.d/             # Defaults on top of php.ini-production
├── tests/
│   └── smoke.sh                # End-to-end check of a built image, no network needed
├── docker-compose.yml          # Local stack: FPM + Mailpit
├── .github/
│   ├── scripts/
│   │   ├── plan.sh             # What ci.yml builds and whether it publishes
│   │   └── publish.sh          # Joins the per-platform digests into tags
│   └── workflows/
│       ├── ci.yml              # Lint, build, smoke test, publish, scheduled rebuilds
│       ├── release.yml         # Semantic release, then ci.yml for the versioned tags
│       ├── commitlint.yml      # Commit message linting on PRs
│       ├── labeler.yml         # Auto-label PRs
│       ├── auto-merge.yml      # Auto-merge Dependabot PRs
│       └── stale.yml           # Stale issue/PR housekeeping
└── .releaserc.json             # Semantic release configuration
```

## How to Contribute

### Reporting Issues

When reporting:

- Specify which image tag you're using, and the platform (amd64/arm64)
- Include Docker version (`docker version`) and whether the container runs as
  root with `USER_ID`/`GROUP_ID` or rootless with `--user`
- Include the environment variables involved, with every secret removed

### Proposing Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test locally (see below)
5. Submit a pull request

## Testing Locally

### Build Test Images

```bash
docker build --build-arg PHP_VERSION=8.4 --build-arg PHP_VARIANT=fpm --target fpm -t php:8.4-fpm-local .
docker build --build-arg PHP_VERSION=8.4 --build-arg PHP_VARIANT=cli --target cli-dev -t php:8.4-cli-dev-local .
```

`PHP_VARIANT` must match the target: `fpm` for `fpm` and `fpm-dev`, `cli` for
`cli` and `cli-dev`.

### Test the Images

```bash
tests/smoke.sh php:8.4-fpm-local fpm
tests/smoke.sh php:8.4-cli-dev-local cli-dev
```

### Lint

```bash
docker run --rm -i hadolint/hadolint < Dockerfile
shellcheck -x rootfs/usr/local/bin/* rootfs/usr/local/lib/docker-php/*.sh \
  rootfs/usr/local/lib/docker-php/init.d/*.sh .github/scripts/*.sh tests/smoke.sh
```

## Code Style

- Comments and any other text inside the code are in English
- Explain *why*, not *what*
- Shell scripts are bash, indented with tabs, and must pass shellcheck
- Every init step must be idempotent and must work both as root and rootless:
  a restarted container runs all of them again
- A new environment variable comes with a test in `tests/smoke.sh` and a line
  in the README tables

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org). Allowed
types are the conventional ones plus `deps` (used by Dependabot):

```bash
feat: add the mongodb extension to the optional ones
fix(msmtp): quote passwords with spaces
docs(readme): document FPM_POOL_*
deps: bump supercronic to 0.2.52
chore: tidy up the compose file
```

Commit types drive the release: `feat` bumps the minor version, `fix`,
`perf`, `refactor`, `deps` and `docs(readme)` bump the patch version, and a
`BREAKING CHANGE` footer bumps the major version. Renaming or removing an
environment variable is a breaking change.

## Build Workflow

1. **On pull request and push to `main`** — lint, build every PHP branch and
   variant on amd64 and arm64, smoke test, no push
2. **On release** — `release.yml` calls `ci.yml`, which publishes every image
   with its `-vX.Y.Z` tag and moves the rolling tags
3. **Daily** (03:17 UTC) — rebuild from the latest release the images whose
   official base image moved, and republish them
4. **Weekly** (Monday, 04:43 UTC) — rebuild and republish everything
5. **Manual trigger** — "Actions" tab → "Run workflow", optionally with a
   release version

## Questions?

- Open a [Discussion](https://github.com/xaas-hub/docker-php/discussions)
- Check the [Documentation](https://github.com/xaas-hub/docker-php)

## License

By contributing, you agree your contributions will be licensed under the MIT
License.
