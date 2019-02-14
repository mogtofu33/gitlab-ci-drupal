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

red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'

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

Usage:
  ${_ME} cp_to_docker
  docker exec -it ci-drupal /scripts/${_ME} all
  docker exec -it ci-drupal /scripts/${_ME} lint

Local arguments:
  cp_to_docker      Helper to copy files in the container after up, must be run locally!

Arguments when run in the docker container ci-drupal:
  all              Run all tests.

  Grouped tests:
    unit             Run unit tests.
    lint             Run linters.
    qa               Run code quality.
    metrics          Rum stats and metrics.
    clean            Remove reports previously generated.

  Any individual tests:
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

_cp_to_docker() {

  if ! [ -x "$(command -v docker)" ]; then
    printf "\\n%s[ERROR] Missing docker!%s\\n\\n" "${red}" "${end}"
    exit 1
  else
    printf "%sCopying config files%s\\n" "${blu}" "${end}"
    docker cp .eslintignore ci-drupal:/var/www/html/.eslintignore
    docker cp .phpmd.xml ci-drupal:/var/www/html/.phpmd.xml
    docker cp .phpqa.yml ci-drupal:/var/www/html/.phpqa.yml
    docker cp .sass-lint.yml ci-drupal:/var/www/html/.sass-lint.yml
    docker cp .stylelintrc.json ci-drupal:/var/www/html/.stylelintrc.json
    docker cp RoboFile.php ci-drupal:/var/www/html/RoboFile.php
    docker cp .gitlab-ci/phpunit.local.xml ci-drupal:/var/www/html/core/phpunit.xml
    docker cp .gitlab-ci/settings-ci.php ci-drupal:/var/www/html/sites/default/settings.php
    printf "%s -- Done%s\\n" "${blu}" "${end}"
  fi
}

_set_variables() {
  WEB_ROOT="/var/www/html"

  # Simulate web if using included Drupal.
  if ! [ -d "/var/www/html/web" ]; then
    ln -s /var/www/html/ /var/www/html/web
  fi

  if [ -d "/var/www/html/web" ]; then
    WEB_ROOT="/var/www/html/web"
  fi

  REPORT_DIR="/var/www/reports"

  if ! [ -d "${REPORT_DIR}" ]; then
    mkdir -p "${REPORT_DIR}"
  fi

  # Variables used in gitlab-ci.yml except the previous.
  TESTS="custom"
  TOOLS="--tools phpcs:0,phpmd,phpcpd,parallel-lint"
  BEST_PRATICES="phpcs:0"
  PHP_CODE="${WEB_ROOT}/modules/custom,${WEB_ROOT}/themes/custom"
  JS_CODE="${WEB_ROOT}/**/custom/**/*.js"
  CSS_FILES="${WEB_ROOT}/(themes|modules|profiles)/custom/**/css/*.css"
  SCSS_FILES="${WEB_ROOT}/(themes|modules|profiles)/custom/**/scss/*.scss"
  SASS_CONFIG="./.sass-lint.yml"
  PHPQA_IGNORE_DIRS="--ignoredDirs vendor,bootstrap,tests"
  PHPQA_IGNORE_FILES="--ignoredFiles Readme.md,style.css,print.css,*Test.php"
  PHPQA_REPORT="--report --buildDir ${REPORT_DIR}"
  PHPQA_PHP_CODE="--analyzedDirs ${PHP_CODE} ${PHPQA_IGNORE_DIRS} ${PHPQA_IGNORE_FILES}"
  PHPQA_ALL_CODE="--analyzedDirs ${WEB_ROOT} ${PHPQA_IGNORE_DIRS} ${PHPQA_IGNORE_FILES}"
}

_prepare() {
  chmod +x /scripts/run-tests-ci-locally.sh

  # Prepare needed folders.
  mkdir -p ${WEB_ROOT}/sites/simpletest/browser_output
  chmod -R 777 ${WEB_ROOT}/sites/simpletest
  chown -R www-data:www-data ${WEB_ROOT}/sites/simpletest

  cd "${WEB_ROOT}"
}

_security_checker() {
  printf "\\n%s[info] Perform job 'Security report'%s\\n\\n" "${blu}" "${end}"

  security-checker security:check > ${REPORT_DIR}/security-check-report.txt
  cat ${REPORT_DIR}/security-check-report.txt
}

_unit_kernel() {
  printf "\\n%s[info] Perform job 'Unit and kernel tests'%s\\n\\n" "${blu}" "${end}"

  robo test:suite "${TESTS}unit,${TESTS}kernel" "${REPORT_DIR}/unit-kernel" "0"
}

_code_coverage() {
  printf "\\n%s[info] Perform job 'Code coverage'%s\\n\\n" "${blu}" "${end}"

  mkdir -p ${REPORT_DIR}/coverage-html
  robo test:coverage "${TESTS}unit,${TESTS}kernel" "${REPORT_DIR}" "0"
}

_functional() {
  printf "\\n%s[info] Perform job 'Functional'%s\\n\\n" "${blu}" "${end}"

  # Permission problem with robo.
  # robo test:suite "${TESTS}functional" "${REPORT_DIR}/functional" "0"

  mkdir -p ${REPORT_DIR}/functional/
  if ! [ -f "${REPORT_DIR}/functional/phpunit.html" ]; then
    touch ${REPORT_DIR}/functional/phpunit.html
  fi
  chown www-data:www-data ${REPORT_DIR}/functional/phpunit.html
  sudo -E -u www-data \
    /usr/local/bin/phpunit --verbose -c web/core \
    --testsuite ${TESTS}functional \
    --testdox-html ${REPORT_DIR}/functional/phpunit.html
  
  cp -fr ${WEB_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional/
}

_functional_js() {
  printf "\\n%s[info] Perform job 'Functional Js'%s\\n\\n" "${blu}" "${end}"

  /scripts/start-selenium-standalone.sh&
  sleep 5s
  # curl -s http://localhost:4444/wd/hub/status | jq '.'

  robo test:suite "${TESTS}functional-javascript" "${REPORT_DIR}/functional_javascript" "0"
}

_nightwatch() {
  printf "\\n%s[info] Perform job 'Nightwatch Js'%s\\n\\n" "${blu}" "${end}"

  cd core
  yarn test:nightwatch --skiptags core
  cd "${WEB_ROOT}"
}

_code_quality() {
  printf "\\n%s[info] Perform job 'Code quality'%s\\n\\n" "${blu}" "${end}"

  phpqa ${PHPQA_REPORT}/code_quality ${TOOLS} ${PHPQA_PHP_CODE}
}

_best_practices() {
  printf "\\n%s[info] Perform job 'Best practices'%s\\n\\n" "${blu}" "${end}"

  sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml
  phpqa ${PHPQA_REPORT}/best_practices --tools ${BEST_PRATICES} ${PHPQA_PHP_CODE}
}

_eslint() {
  printf "\\n%s[info] Perform job 'Js lint'%s\\n\\n" "${blu}" "${end}"

  eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json ${JS_CODE}
  eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json --format html --output-file ${REPORT_DIR}/js-lint-report.html ${JS_CODE}
}

_stylelint() {
  printf "\\n%s[info] Perform job 'Css lint'%s\\n\\n" "${blu}" "${end}"

  stylelint --config-basedir /root/node_modules/ \
    --config .stylelintrc.json -f verbose "${CSS_FILES}" > ${REPORT_DIR}/css-lint-report.txt
  cat ${REPORT_DIR}/css-lint-report.txt

  stylelint -s scss --config-basedir /root/node_modules/ \
    --config .stylelintrc.json -f verbose "${SCSS_FILES}" > ${REPORT_DIR}/scss-lint-report.txt
  cat ${REPORT_DIR}/scss-lint-report.txt
}

_sass_lint() {
  printf "\\n%s[info] Perform job 'Sass lint'%s\\n\\n" "${blu}" "${end}"

  sass-lint --config ${SASS_CONFIG} --verbose --no-exit
  sass-lint --config ${SASS_CONFIG} --verbose --no-exit --format html --output ${REPORT_DIR}/sass-lint-report.html
}

_phpmetrics() {
  printf "\\n%s[info] Perform job 'Php metrics'%s\\n\\n" "${blu}" "${end}"

  phpqa ${PHPQA_REPORT}/phpmetrics --tools phpmetrics ${PHPQA_PHP_CODE}
}

_phpstat() {
  printf "\\n%s[info] Perform job 'Php stats'%s\\n\\n" "${blu}" "${end}"

  phpqa ${PHPQA_REPORT}/phpstat --tools phploc,pdepend ${PHPQA_PHP_CODE}
}

_clean() {
  printf "%sClean reports%s\\n" "${blu}" "${end}"
  rm -rf ${REPORT_DIR}/*
  printf "%s -- Done%s\\n" "${blu}" "${end}"
  exit 0
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

_unit() {
  _security_checker
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
  fi

  if [ "${_CMD}" == "cp_to_docker" ]; then
    if ! [ -f "/.dockerenv" ]; then
      _cp_to_docker
      printf "\\n%s[Info] This is the only command that can be run without docker, other commands must be as:\\ndocker exec -it ci-drupal /scripts/${_ME}%s\\n\\n" "${blu}" "${end}"
      exit 0
    else
      printf "\\n%s[Error] Can not be run in docker wrapper.%s\\n\\n" "${red}" "${end}"
      exit 1
    fi
  fi

  if ! [ -f "/.dockerenv" ]; then
    printf "\\n%s[Error] only cp_to_docker can be run directly, other commands must use docker, eg:\\ndocker exec -it ci-drupal /scripts/${_ME}%s\\n\\n" "${red}" "${end}"
    exit 1
  fi

  # Run command if exist.
  __call="_${_CMD}"
  if [ "$(type -t "${__call}")" == 'function' ]; then
    _set_variables
    _prepare
    $__call
    printf "\\n%s -- Done, visit reports/ for results%s\\n\\n" "${blu}" "${end}"
  else
    _help
  fi
}

# Call `_main` after everything has been defined.
_main

