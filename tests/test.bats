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
  run ddev start -y
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
  echo 'SKIP_CHECKS="30-database 60-custom"' >> .ddev/project-status/config
  run ddev project-status -q
  assert_success
  assert_output "project-status: project is up to date (0 checks, 4 not applicable)."

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
