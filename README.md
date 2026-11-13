[![tests](https://github.com/cosmoblonde/ddev-project-status/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/cosmoblonde/ddev-project-status/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/cosmoblonde/ddev-project-status)](https://github.com/cosmoblonde/ddev-project-status/commits)
[![release](https://img.shields.io/github/v/release/cosmoblonde/ddev-project-status)](https://github.com/cosmoblonde/ddev-project-status/releases/latest)

# DDEV Project Status

* [Overview](#overview)
* [Installation](#installation)
* [Commands](#commands)
* [Files](#files)
* [Configuration](#configuration)
* [Language and own texts](#language-and-own-texts)
* [Bundled checks](#bundled-checks)
* [Writing own checks](#writing-own-checks)
* [Tests](#tests)
* [Credits](#credits)

## Overview

Checks on every `ddev start` whether a project is up to date and prints hints only. It installs nothing, does not
write to the database and never fails the start.

Typical situation after `git pull` or a branch switch:

```text
my-project

Checks
  [WARN]  Composer packages do not match composer.lock
  [WARN]  node_modules does not match package-lock.json

Next steps
  [WARN]  Composer packages do not match composer.lock
          ddev composer install

  [WARN]  node_modules does not match package-lock.json
          ddev exec -d /var/www/html/frontend npm ci

project-status: 2 problem(s) found, all checks with "ddev project-status -v".
```

Update and build routines are deliberately not part of this add-on: framework add-ons or project commands provide
them. `project-status` only shows the matching command as next step.

Checks are plain executables in any language (bash, PHP, Python, Node, ...). The exit code is the status, stdout the
message. Projects add their own checks next to the bundled ones.

## Installation

```bash
ddev add-on get cosmoblonde/ddev-project-status
ddev restart
```

Then adjust `.ddev/project-status/config` and commit the `.ddev` directory.

The `post-start` hook comes with `config.project-status.yaml`. DDEV adds hooks from `config.*.yaml` to those in
`config.yaml`, so no entry in `config.yaml` is needed and existing hooks keep working.

Remove with `ddev add-on remove project-status`. Own checks, own texts and the `config` stay in place.

## Commands

```bash
ddev project-status      # problems and next steps only
ddev project-status -v   # all checks including not applicable ones, plus stderr of the checks
ddev project-status -i   # also project data (URL, TYPO3, PHP, database, web server, Node)
ddev project-status -c   # also the list of project commands
ddev project-status -a   # everything, same as -v -i -c
ddev project-status -q   # summary line only
ddev project-commands    # project commands with their "## Description:" line
```

Short options can be combined (`-iv`). The hook calls `project-status --hook`; whether it runs and with which options
is set in the `config` (`HOOK`, `HOOK_OPTIONS`).

## Files

```text
.ddev/
├── config.project-status.yaml   # post-start hook
├── commands/web/
│   ├── project-status
│   └── project-commands
└── project-status/
    ├── config                   # project settings, never overwritten by updates
    ├── config.example           # template with all settings
    ├── lib/output.sh            # shared output
    ├── lib/i18n.sh              # text catalogs, function t
    ├── lang/                    # text catalogs en, de and own *.custom
    └── checks/                  # bundled and own checks
```

Files containing `#ddev-generated` are replaced by a later `ddev add-on get`. To change a bundled check, either
remove that marker (the file is then kept on updates) or, better, write an own check and switch the bundled one off
with `SKIP_CHECKS`.

## Configuration

`.ddev/project-status/config`, format `KEY="value"`, lists separated by spaces, paths relative to the project root.
Every value is available to the checks as environment variable.

| Setting | Default | Meaning |
|---------|---------|---------|
| `OUTPUT_LANGUAGE` | `en` | language of all messages, see [Language and own texts](#language-and-own-texts) |
| `BRAND` | empty | name in front of the project name in the header, e.g. your agency |
| `HOOK` | `true` | `false`: the hook does not run |
| `HOOK_OPTIONS` | empty | options for the hook run, e.g. `-i` |
| `TIMEOUT` | `20` | seconds per check |
| `SKIP_CHECKS` | empty | checks to leave out, file name with or without extension, e.g. `30-database` |
| `COMPOSER_DIR` | `.` | directory containing `composer.json` |
| `FRONTEND_DIR` | empty | directory containing `package.json`, empty: no frontend |
| `REQUIRED_DIRS` | empty | folders that must exist; missing ones are created |
| `REQUIRED_ASSETS` | empty | build results that must exist |
| `LARGE_FILE_MB` | `50` | `57-sync-size` reports files above this size |
| `LARGE_DIR_MB` | `500` | `57-sync-size` reports folders above this size |
| `COMPOSER_HINT` | `ddev composer install` | next step for Composer problems |
| `NPM_HINT` | `npm ci` in `FRONTEND_DIR` | next step for npm problems |
| `BUILD_HINT` | `npm run build` in `FRONTEND_DIR` | next step for missing build results |

Projects with an own update command point the three hints to it, e.g. `COMPOSER_HINT="ddev project-update"`.

Updates of the add-on leave the `config` untouched. New settings then only appear in `config.example` and use their
default until they are copied into the `config`.

## Language and own texts

All messages live in text catalogs in `.ddev/project-status/lang/`, one text per line:

```text
# comment
composer.outdated = Composer packages do not match composer.lock
database.ok = Database contains %s tables
```

The text is a `printf` format: `%s` for values, a literal percent sign as `%%`.

| File | Content | On updates |
|------|---------|------------|
| `lang/en` | English texts, default | replaced |
| `lang/de` | German texts | replaced |
| `lang/<language>.custom` | own texts and overrides, e.g. for own checks | kept |

Load order is `en`, `en.custom`, `<language>`, `<language>.custom`; later files win. A text missing in the chosen
language falls back to English, a missing key is printed as it is. Another language only needs a file
`lang/<language>.custom` (e.g. `fr.custom`) and `OUTPUT_LANGUAGE="fr"`.

The `## Description:` lines of the commands cannot be translated: DDEV reads them from the file, they stay English.

## Bundled checks

| Check | Checks | Not applicable (SKIP) when |
|-------|--------|----------------------------|
| `10-composer` | `vendor/` exists and matches `composer.lock` (`composer install --dry-run`, no network) | no `composer.json`; `composer.lock` lacks packages from `composer.json` (see `15-composer-lock`) |
| `15-composer-lock` | `composer.lock` matches `composer.json` and the PHP version and extensions of the web container (`composer validate`, `composer check-platform-reqs --lock`, no network) | no `composer.json` or no `composer.lock` |
| `20-npm` | `node_modules/` matches `package-lock.json`; detects npm >= 7 and npm 6 (`lockfileVersion` 1) | no `FRONTEND_DIR` or no `package.json` |
| `30-database` | database contains tables (MySQL/MariaDB or PostgreSQL, read only) | – |
| `40-folders` | folders from `REQUIRED_DIRS` exist, missing ones are created | no `REQUIRED_DIRS` |
| `50-assets` | build results from `REQUIRED_ASSETS` exist | no `REQUIRED_ASSETS` |
| `55-typo3-solr` | [ddev/ddev-typo3-solr](https://github.com/ddev/ddev-typo3-solr) is installed, Solr answers and has all cores from `.ddev/typo3-solr/config.yaml` (admin API, read only) | no `.ddev/typo3-solr/config.yaml` |
| `57-sync-size` | no files over `LARGE_FILE_MB` and no folders over `LARGE_DIR_MB` in the Mutagen sync | project does not use Mutagen |

Checks compare contents, not file times: with Mutagen, modification times do not reach the container.

Own checks start at `60-`, so bundled checks added later never collide with them.

**composer.lock out of step:** `composer install` installs from `composer.lock` and only warns when `composer.json`
changed since, so `vendor/` can match an outdated lock file. That happens after a `git pull` or branch switch that
changes `composer.json` alone, or when `composer.json` or `composer.lock` is copied from a server. The conflict then
only shows on the next `composer update`. `15-composer-lock` reports it beforehand:

- **does not match composer.json** (WARN): the content hash in `composer.lock` is outdated. `ddev composer update
  --dry-run` shows what an update would change; if the change to `composer.json` was not intended, check out the
  matching `composer.lock` or `composer.json` instead.
- **does not fit the PHP platform** (FAIL): locked packages need another PHP version or a missing extension, typical
  for a `composer.lock` resolved on a server. `config.platform` is ignored here on purpose, the check compares with the
  real web container. Fix: `php_version` in `.ddev/config.yaml`, the extension, or a `composer update` for this platform.
- **config.platform.php differs** (INFO): `composer.json` sets a PHP version for resolving that is not the one DDEV
  runs. Fine if it is the production version on purpose; then DDEV should usually run the same version.

**TYPO3 Solr "running but not ready":** the Solr container runs, but Solr itself did not start, so every request
fails and `ddev solrctl apply` cannot create cores. A common cause is file permissions: `solrctl` copies `solr.xml`,
`typo3lib/` and the configsets with `docker cp`, which keeps owner and mode from the host. If these files are readable
by their owner only (mode `600`, as composer sometimes extracts them), the `solr` user in the container cannot read
them. `ddev logs -s typo3-solr` then shows "Could not load SOLR configuration". Fix: after copying, run
`docker exec -u 0 ddev-<project>-typo3-solr chown -R solr:solr /var/solr/data` (or add it to `solrctl`), then
`ddev solrctl apply` again.

**Large files and folders in the Mutagen sync:** Mutagen keeps every synced file twice, on the host and in the Docker
volume. `57-sync-size` reports the folders of files over `LARGE_FILE_MB`, typically database dumps, and folders over
`LARGE_DIR_MB`, which catches many small files. A large folder is named at its topmost level. The docroot and folders
above it are never named: excluding them would take the site out of the container, so large files directly in the
docroot or the project root are named one by one.

The check leaves out `vendor/`, `node_modules/`, `.git/`, the `upload_dirs` and everything under `ignore: paths:` in
`.ddev/mutagen/mutagen.yml`; negated patterns (`!`) are not evaluated. The message names the five largest entries, `-v`
lists all of them.

A reported folder may hold data the site needs, so only exclude what the container can do without. To exclude a
folder, remove the `#ddev-generated` line from `mutagen.yml`, otherwise DDEV overwrites the file, add the folder and run
`ddev mutagen reset`:

```yaml
sync:
  defaults:
    ignore:
      paths:
        - "/cb_dumps"
```

## Writing own checks

Every executable file in `.ddev/project-status/checks/` is a check, in any language; the shebang line decides. Checks
run in the web container, in the project root, in name order. Name own checks from `60-` on and leave out the
`#ddev-generated` marker.

**Exit code = status**

| Exit code | Status | Shown |
|-----------|--------|-------|
| 0 | OK | with `-v` only |
| 1 | WARN | always, counts as problem |
| 2 | FAIL | always, counts as problem |
| 3 | SKIP, not applicable to this project | with `-v` only, does not count |
| other, timeout | the check itself is broken | as WARN with the name of the check |

**stdout**

* first line without prefix: the message
* `next: <command>`: next step, listed below the status line of the check; the same command twice in one check is
  shown once
* `info: <message>`: something harmless the check did (always shown)

**stderr** is shown with `-v` only, useful for debug output.

Rules: fast, repeatable, offline, no writes to the database or to files under version control.

PHP example:

```php
#!/usr/bin/env php
<?php
// Checks that the TYPO3 encryption key is configured
if (getenv('TYPO3_ENCRYPTION_KEY') === false) {
    echo "TYPO3 encryption key is missing\n";
    echo "next: ddev config --web-environment-add=TYPO3_ENCRYPTION_KEY=...\n";
    exit(1);
}
echo "Encryption key is set\n";
exit(0);
```

Bash example:

```bash
#!/usr/bin/env bash
# Checks that the Solr core answers
[[ -n "${SOLR_URL:-}" ]] || { echo "No SOLR_URL configured"; exit 3; }
if curl -fs "$SOLR_URL/admin/ping" >/dev/null; then
  echo "Solr answers"
  exit 0
fi
echo "Solr does not answer"
echo "next: ddev restart"
exit 1
```

**Translated messages:** every check gets `OUTPUT_LANGUAGE` and `PROJECT_STATUS_DIR` as environment variables. Bash
checks can use the text catalogs directly and keep their texts in `lang/*.custom`:

```bash
#!/usr/bin/env bash
source "$PROJECT_STATUS_DIR/lib/i18n.sh"
[[ -f public/.htaccess ]] && { t htaccess.ok; exit 0; }
t htaccess.missing
exit 1
```

```text
# lang/en.custom
htaccess.ok = public/.htaccess present
htaccess.missing = public/.htaccess is missing
```

Checks in other languages evaluate `OUTPUT_LANGUAGE` themselves or report in one language.

Remember `chmod +x`. New or changed checks and changes to the `config` count at once: `project-status` reads them
from `/var/www/html/.ddev/project-status`, which Mutagen keeps in sync. Changed commands (`commands/web/`) need a
`ddev restart`, because DDEV copies them to `/mnt/ddev_config` on start.

## Tests

`tests/test.bats` follows the [DDEV add-on template](https://github.com/ddev/ddev-addon-template): it creates an empty
project, installs the add-on and checks the output, an own PHP check, `SKIP_CHECKS`, German output, own texts and large data in the Mutagen sync.
GitHub Actions run it on every push. Locally, with `bats-core`, `bats-assert`, `bats-file` and `bats-support`
installed, in the add-on directory:

```bash
bats ./tests/test.bats
```

## Credits

**Contributed and maintained by [cosmoblonde](https://github.com/cosmoblonde)**
