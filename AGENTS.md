# AGENTS.md

Instructions for AI agents working on this repository. Everything a human
contributor needs is in [CONTRIBUTING](.github/CONTRIBUTING.md): read it, this
file does not repeat it.

## Hard rules

- **The base is the official php image, unchanged.** No PHP compiled here, no
  other base: the security model is that a PHP release reaches the tags as
  soon as docker-library publishes it (see `plan.sh`).
- **Every init step must work as root and rootless**, and be idempotent: it
  runs at every start, also of a restarted container. Root-only work (user
  remapping, locales) must degrade to a log line without root, never fail.
- **Secrets never reach PHP or the logs.** `MSMTP_PASSWORD` is unset in
  `50-msmtp.sh`; any new secret variable needs the same treatment and a
  `_FILE` variant.
- **Do not set `APP_ENV` in the image**: Laravel's `.env` must keep winning
  when the variable is not passed.
- **Never read `.env`.** Only `.env.dist` is tracked.
- **Do not edit `CHANGELOG.md`.** semantic-release writes it from the commit
  log.
- Renaming or removing an environment variable, a tag or a build argument is
  a breaking change: say so in the commit footer.

## Commands

Everything runs in Docker. If you cannot run it, say which commands have to be
run and what output to look for.

```bash
docker build --build-arg PHP_VARIANT=fpm --target fpm -t php:local .
tests/smoke.sh php:local fpm
```

Lint as described in the header of `.megalinter.yml`, which mirrors `ci.yml`.

## Conventions

- Code, comments and commit messages in English. Comments explain why, not
  what.
- Conventional Commits, plus the `deps` type: the type decides the release
  (see CONTRIBUTING). Body lines up to 150 characters.
- Shell scripts are bash, must pass `shellcheck -x` and are indented with
  tabs, like the existing ones.
- Environment variables: features use their own prefix (`MSMTP_`,
  `SUPERCRONIC_`), directives go through the generic `PHP_INI_` and
  `FPM_POOL_` mapping in `env_to_ini`. Do not add a dedicated variable for a
  single php.ini directive.
- A new variable or behaviour comes with an assertion in `tests/smoke.sh` and
  a line in the README tables.
- A new optional extension is a word in `PHP_EXTENSIONS_OPTIONAL`; if it is
  compiled against igbinary or msgpack, add it to `PHP_EXTENSION_DEPS` in
  `init.d/30-php.sh`.
- Pinned downloads (Supercronic, WP-CLI) carry their checksum: bump both.

## Private notes

`agents/` is gitignored. If your checkout has it, it holds the maintainer's
notes: read what is relevant to the task, never reference it from versioned
files.
