#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  export GITHUB_REPO=cosmoblonde/ddev-project-status

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH:-}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  export CI=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  # the Mutagen daemon outlives the test: if it inherits file descriptor 3, bats waits for it forever
  run ddev start -y 3>&-
  assert_success
}

health_checks() {
  # empty project: database is empty, everything else is not applicable
  run ddev project-status -v
  assert_success
  assert_output --partial "[FAIL]  Database is empty"
  assert_output --partial "[SKIP]  No composer.json"
  assert_output --partial "ddev import-db --file=<dump.sql.gz>"

  # own check in PHP, following the contract: exit code 1 = WARN, next: line = next step
  cat > .ddev/project-status/checks/60-custom <<'PHP'
#!/usr/bin/env php
<?php
echo "own check reports something\nnext: ddev my-command\n";
exit(1);
PHP
  chmod +x .ddev/project-status/checks/60-custom
  run ddev project-status
  assert_success
  assert_output --partial "[WARN]  own check reports something"
  assert_output --partial "ddev my-command"

  # skip by config, quiet output
  echo 'SKIP_CHECKS="30-database 57-sync-size 60-custom"' >> .ddev/project-status/config
  run ddev project-status -q
  assert_success
  # the number of not applicable checks grows with new bundled checks, the release test runs an older version
  assert_output --regexp '^project-status: project is up to date \(0 checks, [0-9]+ not applicable\)\.$'

  run ddev project-commands
  assert_success
  assert_output --partial "project-status"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  assert_file_exist .ddev/project-status/config
  run ddev restart -y
  assert_success
  assert_output --partial "project-status:"
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "update from v1.3.0, where project-status was a web command" {
  set -eu -o pipefail
  run ddev add-on get "${GITHUB_REPO}" --version v1.3.0
  assert_success
  assert_file_exist .ddev/commands/web/project-status
  run ddev add-on get "${DIR}"
  assert_success
  assert_file_not_exist .ddev/commands/web/project-status
  assert_file_exist .ddev/commands/host/project-status
  run ddev restart -y
  assert_success
  assert_output --partial "project-status:"
}

@test "German output and own texts" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  echo 'OUTPUT_LANGUAGE="de"' >> .ddev/project-status/config
  echo 'assets.none = Hier gibt es keine Assets' > .ddev/project-status/lang/de.custom
  run ddev project-status -v
  assert_success
  assert_output --partial "[FAIL]  Datenbank ist leer"
  assert_output --partial "[SKIP]  Hier gibt es keine Assets"
  assert_output --partial "Nächste Schritte"
}

@test "Next steps grouped by check" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  echo 'SKIP_CHECKS="57-sync-size"' >> .ddev/project-status/config
  cat > .ddev/project-status/checks/60-custom <<'SH'
#!/usr/bin/env bash
echo "own check reports something"
echo "next: ddev my-command"
echo "next: ddev my-command"
echo "next: ddev restart"
exit 1
SH
  cat > .ddev/project-status/checks/61-custom <<'SH'
#!/usr/bin/env bash
echo "second check reports something"
echo "next: ddev restart"
exit 1
SH
  chmod +x .ddev/project-status/checks/60-custom .ddev/project-status/checks/61-custom
  run ddev project-status
  assert_success
  # every check with its steps below its status line, a step repeated within a check is shown once
  assert_output --partial "Next steps
  [FAIL]  Database is empty
          ddev import-db --file=<dump.sql.gz>

  [WARN]  own check reports something
          ddev my-command
          ddev restart

  [WARN]  second check reports something
          ddev restart
"
}

@test "Git branch and upstream" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev project-status -v
  assert_success
  assert_output --partial "[SKIP]  No git repository"

  # a local bare repository as origin keeps the test offline
  g() { git -c user.name=test -c user.email=test@example.com "$@"; }
  origin="${BATS_TEST_TMPDIR}/origin.git"
  g init -q --bare -b main "${origin}"
  g init -q -b main
  g commit -q --allow-empty -m one
  g remote add origin "${origin}"
  g push -q -u origin main
  g branch develop
  g push -q -u origin develop
  g fetch -q origin

  run ddev project-status -i
  assert_success
  assert_output --partial "[WARN]  Working on branch main, which is not meant for development"
  assert_output --partial "git switch -c feature/<name>"
  assert_output --regexp 'Branch +main'

  g switch -q -c feature/test
  run ddev project-status -v
  assert_success
  assert_output --partial "[OK]    On branch feature/test, main, develop in step with the upstream (as of the last fetch)"

  # main behind: pushed from another clone and fetched; develop ahead: committed and not pushed
  g clone -q "${origin}" "${BATS_TEST_TMPDIR}/other"
  g -C "${BATS_TEST_TMPDIR}/other" commit -q --allow-empty -m two
  g -C "${BATS_TEST_TMPDIR}/other" push -q origin main
  g fetch -q origin
  g switch -q develop
  g commit -q --allow-empty -m three
  g switch -q feature/test
  run ddev project-status
  assert_success
  assert_output --partial "[WARN]  main is 1 commit(s) behind origin/main – develop is 1 commit(s) ahead of origin/develop, not pushed"
  assert_output --partial "git fetch origin main:main"
  assert_output --partial "git log --oneline origin/develop..develop"

  # the comparison is only as fresh as the last fetch
  touch -t 202001010000 .git/FETCH_HEAD
  run ddev project-status
  assert_success
  assert_output --regexp '\[INFO\]  Comparison with the upstream as of the last fetch [0-9]+ days ago: git fetch'

  # own lists in the config; TRACKED_BRANCHES is read on the host as well
  echo 'PROTECTED_BRANCHES="feature/test"' >> .ddev/project-status/config
  echo 'TRACKED_BRANCHES="develop"' >> .ddev/project-status/config
  run ddev project-status
  assert_success
  assert_output --partial "[WARN]  Working on branch feature/test, which is not meant for development – develop is 1 commit(s) ahead"
  refute_output --partial "main is 1 commit(s) behind"
}

@test "TYPO3 Solr configured without the Solr add-on" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # no Solr configuration: not applicable
  run ddev project-status -v
  assert_success
  assert_output --partial "[SKIP]  No TYPO3 Solr configuration"

  # configuration of ddev/ddev-typo3-solr present, but the add-on itself (docker-compose.typo3-solr.yaml) is missing
  mkdir -p .ddev/typo3-solr
  printf 'configsets:\n  - name: "ext_solr"\n    cores:\n      - name: "core_en"\n' > .ddev/typo3-solr/config.yaml
  run ddev project-status
  assert_success
  assert_output --partial "[FAIL]  TYPO3 Solr is configured, but the add-on ddev/ddev-typo3-solr is not installed"
  assert_output --partial "ddev add-on get ddev/ddev-typo3-solr"
}

@test "Large files and folders in the Mutagen sync" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  mkdir -p dumps/old vendor/acme frontend/node_modules/acme public uploads
  run ddev config --performance-mode=mutagen --docroot=public --upload-dirs=../uploads
  assert_success
  run ddev restart -y 3>&-
  assert_success

  echo 'LARGE_FILE_MB="2"' >> .ddev/project-status/config
  for file in dumps/big.sql dumps/old/older.sql root.sql vendor/acme/big.bin frontend/node_modules/acme/big.bin public/big.bin uploads/big.bin; do
    dd if=/dev/zero of="${file}" bs=1048576 count=3 2>/dev/null
  done
  # below the limit
  dd if=/dev/zero of=dumps/small.sql bs=1048576 count=1 2>/dev/null
  run ddev mutagen sync
  assert_success

  run ddev project-status
  assert_success
  assert_output --partial "[WARN]  Large files or folders in the Mutagen sync: "
  assert_output --partial "dumps (3 MB)"
  assert_output --partial "dumps/old (3 MB)"
  assert_output --partial "root.sql (3 MB)"
  # never the docroot itself, that would take the site out of the container
  assert_output --partial "public/big.bin (3 MB)"
  refute_output --partial "public ("
  assert_output --partial "ddev mutagen reset"
  refute_output --partial "vendor"
  refute_output --partial "node_modules"
  refute_output --partial "uploads"

  # a large folder of small files, named at its topmost level and covering the large files below it
  mkdir -p public/archive/a public/archive/b
  for file in public/archive/a/1 public/archive/a/2 public/archive/b/1 public/archive/b/2; do
    dd if=/dev/zero of="${file}" bs=1048576 count=2 2>/dev/null
  done
  echo 'LARGE_DIR_MB="5"' >> .ddev/project-status/config
  run ddev mutagen sync
  assert_success
  run ddev project-status
  assert_success
  assert_output --partial "public/archive (8 MB)"
  assert_output --partial "dumps (7 MB)"
  refute_output --partial "public/archive/a"
  refute_output --partial "dumps/old"

  # the message names five entries, -v all of them
  mkdir -p data1 data2 data3 data4 data5
  for number in 1 2 3 4 5; do
    dd if=/dev/zero of="data${number}/big.bin" bs=1048576 count=3 2>/dev/null
  done
  run ddev mutagen sync
  assert_success
  run ddev project-status
  assert_success
  assert_output --partial ", 4 more"
  run ddev project-status -v
  assert_success
  assert_output --regexp 'data[1-5] \(3 MB\)'
  rm -rf data1 data2 data3 data4 data5

  # entries in mutagen.yml count at once; the files are still in the volume until "ddev mutagen reset"
  awk '!/#ddev-generated/; /- "\/.git"/ { print "        - \"/dumps\""; print "        - \"*.sql\""; print "        - \"public/archive\""; print "        - \"big.bin\"" }' .ddev/mutagen/mutagen.yml > mutagen.yml.new
  mv mutagen.yml.new .ddev/mutagen/mutagen.yml
  run ddev mutagen sync
  assert_success
  run ddev project-status -v
  assert_success
  assert_output --partial "[OK]    No files over 2 MB or folders over 5 MB in the Mutagen sync"

  # a limit that is no number must not reach the size calculation
  echo 'LARGE_DIR_MB="big"' >> .ddev/project-status/config
  run ddev mutagen sync
  assert_success
  run ddev project-status
  assert_success
  assert_output --partial 'LARGE_DIR_MB must be a whole number above 0, not "big"'

  # without Mutagen the check does not apply
  run ddev exec "DDEV_MUTAGEN_ENABLED=false /mnt/ddev_config/project-status/runner -v"
  assert_success
  assert_output --partial "[SKIP]  Project does not use Mutagen"
}

@test "composer.lock against composer.json and the PHP platform" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # a path package keeps the test offline
  mkdir -p packages/needs-php
  echo '{"name": "acme/needs-php", "version": "1.0.0", "require": {"php": ">=99.0", "ext-doesnotexist": "*"}}' > packages/needs-php/composer.json
  echo '{"repositories": [{"type": "path", "url": "packages/*"}], "require": {"php": ">=8.0"}}' > composer.json
  run ddev composer install
  assert_success

  run ddev project-status -v
  assert_success
  assert_output --partial "[OK]    Composer packages match composer.lock"
  assert_output --partial "[OK]    composer.lock matches composer.json and the PHP platform"

  # composer.json changed, composer.lock not: vendor/ still matches the lock file, the lock file is outdated
  echo '{"repositories": [{"type": "path", "url": "packages/*"}], "require": {"php": ">=8.1"}}' > composer.json
  run ddev project-status
  assert_success
  assert_output --partial "[WARN]  composer.lock does not match composer.json"
  assert_output --partial "ddev composer update --dry-run"
  refute_output --partial "[WARN]  Composer packages do not match composer.lock"

  # a required package missing in composer.lock: "composer install" cannot help, so 10-composer does not suggest it
  echo '{"repositories": [{"type": "path", "url": "packages/*"}], "require": {"php": ">=8.0", "acme/needs-php": "*"}}' > composer.json
  run ddev project-status -v
  assert_success
  assert_output --partial "[SKIP]  vendor/ not comparable: composer.lock lacks packages from composer.json"
  assert_output --partial "[WARN]  composer.lock does not match composer.json"
  refute_output --partial "ddev composer install"

  # composer.lock resolved for another platform, as by a server with another PHP version
  echo '{"repositories": [{"type": "path", "url": "packages/*"}], "require": {"acme/needs-php": "*"}, "config": {"platform": {"php": "99.0", "ext-doesnotexist": "1.0"}}}' > composer.json
  run ddev composer update
  assert_success
  run ddev project-status
  assert_success
  assert_output --partial "[FAIL]  composer.lock does not fit the PHP platform: "
  assert_output --partial "php >=99.0 (acme/needs-php: "
  assert_output --partial "ext-doesnotexist * (acme/needs-php: n/a)"
  assert_output --partial "ddev composer check-platform-reqs --lock"
  assert_output --regexp 'composer.json sets config.platform.php 99.0, DDEV runs PHP [0-9]+\.[0-9]+'
}
