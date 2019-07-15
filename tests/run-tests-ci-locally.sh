#!/bin/bash

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.yml

###############################################################################
# Environment
###############################################################################

# $_ME
#
# Set to the program's basename.
_ME=$(basename "${0}")

_red=$'\e[1;31m'
_grn=$'\e[1;32m'
_blu=$'\e[1;34m'
_end=$'\e[0m'

# Grab .env files to simulate CI variables.
if [ -f "./.gitlab-ci/.docker-compose.env" ]; then
  . ./.gitlab-ci/.docker-compose.env
else
  printf "%s[ERROR]%s Missing ./.gitlab-ci/.docker-compose.env\\n" "${_red}" "${_end}"
  exit 1
fi

_CMD="${1:-"help"}"

###############################################################################
# Help
###############################################################################

# _help()
#
# Usage:
#   _help
#
# Print the program help information.
_help() {
  cat <<HEREDOC

Locally run Gitlab-ci tests with a docker-compose stack.
Most commands are executed in the ci-drupal container.

Usage:
  ${_ME} all
  ${_ME} status

Arguments:
  cp_to_docker        Helper to copy files in the container after up.
  all                 Run all tests.
  status              Give information and versions of tools.

  Grouped tests:
    security          Run security tests (if any composer.json file).
    unit              Run unit tests.
    lint              Run linters.
    qa                Run code quality.
    metrics           Rum stats and metrics.

  Standalone tests:
    security_checker
    unit_kernel
    code_coverage
    functional
    functional_js
    nightwatch
    code_quality
    best_practices
    eslint
    stylelint
    sass_lint
    phpmetrics
    phpstat

HEREDOC
}

###############################################################################
# Program Functions
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -w ${DOC_ROOT} ci-drupal "$@"
  fi
}

_dkexec_core() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -w ${WEB_ROOT}/core ci-drupal "$@"
  fi
}

_dkexec_web_apache() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -u www-data -w ${WEB_ROOT} ci-drupal "$@"
  fi
}

_dkexec_core_apache() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -u www-data -w ${WEB_ROOT}/core ci-drupal "$@"
  fi
}

_cp_to_docker() {
  # printf "%s[INFO]%s Copying config files in ci-drupal container\\n" "${_blu}" "${_end}"

  # Place config files in a proper directory.
  _dkexec bash -c "cp -fu /builds/.gitlab-ci/.env.ci /builds/.gitlab-ci/.eslintignore /builds/.gitlab-ci/.phpmd.xml /builds/.gitlab-ci/*.xml /builds/.gitlab-ci/.*.yml /builds/.gitlab-ci/RoboFile.php ${DOC_ROOT}/"
}

_status() {
  _dkexec robo check:drush
  # _dkexec vendor/bin/drush status
  # _dkexec robo drush status
}

_tests_prepare() {
  # Prepare needed folders, reproduce .test_template
  _dkexec cp -u ${DOC_ROOT}/phpunit.local.xml ${WEB_ROOT}/core/phpunit.xml
  _dkexec cp -u ${DOC_ROOT}/.env.ci ${WEB_ROOT}/core/.env

  # RoboFile.php is already at root.
  _dkexec mkdir -p ${WEB_ROOT}/sites/simpletest/browser_output
  _dkexec chmod -R g+s ${WEB_ROOT}/sites/simpletest
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites/simpletest
  # _dkexec chmod -R 777 ${WEB_ROOT}/sites/simpletest
  # Apache launch is entrypoint.
  # _dkexec apache2-foreground&
  _dkexec robo symlink:folders
}

_build() {
  _dkexec robo perform:build
}

_reset() {
  printf "\\n%s[INFO]%s Reset stack to mimic Gitlab-ci\\n" "${_blu}" "${_end}"
  _down
  _up
}

_up() {
  docker-compose -f .gitlab-ci/docker-compose.yml up -d
  printf "Waiting for DB to be initialized...\\n"
  sleep 20s
}

_down() {
  docker-compose -f .gitlab-ci/docker-compose.yml down
}

_unit_kernel() {
  printf "\\n%s[INFO]%s Perform job 'Unit and kernel tests' (unit_kernel)\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec robo test:suite "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_code_coverage() {
  printf "\\n%s[INFO]%s Perform job 'Code coverage' (code_coverage)\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec robo test:coverage "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_functional() {
  printf "\\n%s[INFO]%s Perform job 'Functional' (functional)\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  # Permission problem with robo.
  _dkexec robo test:suite "${PHPUNIT_TESTS}functional"

  # _dkexec mkdir -p ${REPORT_DIR}/functional
  # _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${REPORT_DIR}/functional

  #  printf "\\n%s[INFO]%s Fix permissions...\\n" "${_blu}" "${_end}"
  # _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites

  # _dkexec sudo -E -u www-data \
  #   /usr/local/bin/phpunit \
  #   -c ${WEB_ROOT}/core \
  #   --testsuite ${PHPUNIT_TESTS}functional \
  #   --testdox-html ${REPORT_DIR}/functional/phpunit.html \
  #   --testdox-xml ${REPORT_DIR}/functional/phpunit.xml

  _dkexec bash -c "cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional"
}

_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  # docker exec -d ci-drupal /scripts/start-selenium-standalone.sh
  # sleep 5s
  _dkexec bash -c "curl -s http://localhost:4444/wd/hub/status | jq '.'"

  _dkexec robo test:suite "${PHPUNIT_TESTS}functional-javascript"

  _dkexec bash -c "cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional-javascript"
}

_nightwatch() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  printf "... Patching nightwatch for Drupal profile support.\\n"
  _dkexec bash -c "curl -fsSL https://www.drupal.org/files/issues/2019-02-05/3017176-7.patch -o ${DOC_ROOT}/3017176-7.patch"
  _dkexec_web_apache bash -c "patch -p1 < ${DOC_ROOT}/3017176-7.patch"

  _dkexec_core_apache yarn install
  _dkexec_core yarn test:nightwatch ${NIGHTWATCH_TESTS}
}

_security_checker() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n" "${_blu}" "${_end}"

  _build
  _dkexec security-checker security:check
}

_code_quality() {
  printf "\\n%s[INFO]%s Perform job 'Code quality' (code_quality)\\n" "${_blu}" "${_end}"

  _dkexec phpqa ${PHPQA_REPORT}/code_quality ${TOOLS} ${PHPQA_PHP_CODE}
}

_best_practices() {
  printf "\\n%s[INFO]%s Perform job 'Best practices' (best_practices)\\n" "${_blu}" "${_end}"

  _dkexec sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml
  _dkexec phpqa ${PHPQA_REPORT}/best_practices --tools ${BEST_PRACTICES} ${PHPQA_PHP_CODE}
}

_eslint() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n" "${_blu}" "${_end}"

  # _dkexec eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json ${JS_CODE}
  _dkexec eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json --format html --output-file ${REPORT_DIR}/js-lint-report.html ${JS_CODE}
}

_stylelint() {
  printf "\\n%s[INFO]%s Perform job 'Css lint' (stylelint)\\n" "${_blu}" "${_end}"

  # _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/8.7.x/core/.stylelintrc.json -o ${DOC_ROOT}/.stylelintrc.json
  _dkexec stylelint --config-basedir /var/www/.node/node_modules/ \
    --config ${WEB_ROOT}/core/.stylelintrc.json -f verbose "${CSS_FILES}"
}

_sass_lint() {
  printf "\\n%s[INFO]%s Perform job 'Sass lint' (sass_lint)\\n" "${_blu}" "${_end}"

  # _dkexec sass-lint --config ${SASS_CONFIG} --verbose --no-exit
  _dkexec sass-lint --config ${SASS_CONFIG} --verbose --no-exit --format html --output ${REPORT_DIR}/sass-lint-report.html
}

_phpmetrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (phpmetrics)\\n" "${_blu}" "${_end}"

  _dkexec phpqa ${PHPQA_REPORT}/phpmetrics --tools phpmetrics ${PHPQA_PHP_CODE}
}

_phpstat() {
  printf "\\n%s[INFO]%s Perform job 'Php stats' (phpstat)\\n" "${_blu}" "${_end}"

  _dkexec phpqa ${PHPQA_REPORT}/phpstat --tools phploc,pdepend ${PHPQA_PHP_CODE}
}

_clean() {
  rm -f .env.ci .eslintignore .phpmd.xml .phpqa.yml .sass-lint.yml phpunit.local.xml phpunit.xml RoboFile.php
  rm -rf reports/*
}

_all() {
  _security_checker
  _unit_kernel
  _code_coverage
  _functional
  _functional_js
  _nightwatch
  _code_quality
  _best_practices
  _eslint
  _stylelint
  _sass_lint
  _phpmetrics
  _phpstat
}

_security() {
  _security_checker
}

_unit() {
  _unit_kernel
  _code_coverage
  _functional
  _functional_js
  _nightwatch
}

_lint() {
  _eslint
  _stylelint
  _sass_lint
}

_qa() {
  _code_quality
  _best_practices
}

_metrics() {
  _phpmetrics
  _phpstat
}

###############################################################################
# Main
###############################################################################

# _main()
#
# Usage:
#   _main [<options>] [<arguments>]
#
# Description:
#   Entry point for the program, handling basic option parsing and dispatching.
_main() {

  if [ "${_CMD}" == "help" ]; then
    _help
    exit 0
  elif [ "${_CMD}" == "cp_to_docker" ] || [ "${_CMD}" == "cp" ]; then
    _cp_to_docker
    exit 0
  elif [ "${_CMD}" == "clean" ] || [ "${_CMD}" == "reset" ] || [ "${_CMD}" == "up" ] || [ "${_CMD}" == "down" ]; then
    __call="_${_CMD}"
    $__call
    exit 0
  fi

  # Run command if exist.
  __call="_${_CMD}"
  if [ "$(type -t "${__call}")" == 'function' ]; then
    _cp_to_docker
    $__call
    printf "%s -- Testing done%s" "${_grn}" "${_end}"
    printf "\\n%s -- Visit local folder reports/ for results%s" "${_blu}" "${_end}"
    printf "\\n%s -- Happy testing!%s\\n" "${_blu}" "${_end}"
  else
    _help
  fi
}

# Call `_main` after everything has been defined.
_main
