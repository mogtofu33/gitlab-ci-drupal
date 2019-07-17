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

# Grab .docker-compose.env files to simulate CI variables.
if [ -f "tests/.docker-compose.env" ]; then
  source tests/.docker-compose.env
else
  if [ -f ".docker-compose.env" ]; then
    source .docker-compose.env
  else
    printf "%s[ERROR]%s Missing .docker-compose.env file.\\n" "${_red}" "${_end}"
    exit 1
  fi
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

Arguments:
  all                 Run all tests.
  status              Give information and versions of tools.
  clean               Remove files and reports generated or copied by this script.
  clean_all           Clean + remove a downloaded Drupal project.

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

_status() {
  _dkexec /scripts/run-tests.sh
  docker exec -d ci-drupal /scripts/start-selenium-standalone.sh
  sleep 2s
  _dkexec bash -c "curl -s http://localhost:4444/wd/hub/status | jq '.'"
}

# Replicate Gitlab-ci.yml .test_template
_tests_prepare() {
  printf ">>> [NOTICE] tests_prepare\\n"

  _dkexec bash -c "cp -u ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}"

  _dkexec robo prepare:folders
  
  # Apache launch is entrypoint.
  _dkexec apache2-foreground&

  # Prepare needed folders, reproduce .test_template
  if [ ${CI_TYPE} == 'custom' ];
  then
    _dkexec bash -c "cp -u ${CI_PROJECT_DIR}/tests/phpunit.local.xml ${CI_PROJECT_DIR}/web/core/phpunit.xml"
  else
    _dkexec bash -c "cp -u ${CI_PROJECT_DIR}/tests/phpunit.local.xml ${WEB_ROOT}/core/phpunit.xml"
  fi

  # RoboFile.php is already at root.
  _dkexec mkdir -p "${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output"
  _dkexec chmod -R g+s "${BROWSERTEST_OUTPUT_DIRECTORY}"
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${BROWSERTEST_OUTPUT_DIRECTORY}

}

# Replicate Build job.
_build() {
  printf ">>> [NOTICE] build\\n"
  _simulate_cache

  _dkexec bash -c "cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}"

  _dkexec robo perform:build

  _create_artifacts
}

_create_artifacts() {

  printf ">>> [NOTICE] Uploading artifacts...\\n"

  if ! [ -f tmp/artifacts.tgz ] && [ -f web/index.php ]
  then
    mkdir -p tmp
    tar -czf tmp/artifacts.tgz vendor web drush scripts composer.json composer.lock .env.example load.environment.php
  else
    printf ">>> [SKIP] artifacts already exist or not a project.\\n"
  fi
}

# Replicate Build job artifacts.
_extract_artifacts() {
  printf ">>> [NOTICE] extract_artifacts\\n"
  if [ -f tmp/artifacts.tgz ]
  then
    mv tmp/artifacts.tgz .
    _dkexec tar -xzf ${CI_PROJECT_DIR}/artifacts.tgz
    mkdir -p tmp
    mv artifacts.tgz tmp/
  else
    printf "\\n>>> [SKIP] No artifacts!\\n" "${_blu}" "${_end}"
  fi
}

# Replicate Build job cache.
_simulate_cache() {
  printf ">>> [NOTICE] simulate_cache\\n"
  _extract_artifacts
  rm -rf drush scripts composer.json composer.lock .env.example load.environment.php
}

####### Tests jobs

_unit_kernel() {
  printf "\\n%s[INFO]%s Perform job 'Unit and kernel tests' (unit_kernel)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare
  _dkexec robo test:suite "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_code_coverage() {
  printf "\\n%s[INFO]%s Perform job 'Code coverage' (code_coverage)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare
  _dkexec robo test:coverage "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_functional() {
  printf "\\n%s[INFO]%s Perform job 'Functional' (functional)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites/
  _dkexec sudo -E -u ${APACHE_RUN_USER} robo test:suite "${PHPUNIT_TESTS}functional"

  _dkexec bash -c "cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional"
}

_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  # Starting Selenium.
  docker exec -d ci-drupal /scripts/start-selenium-standalone.sh
  sleep 5s
  _dkexec bash -c "curl -s http://localhost:4444/wd/hub/status | jq '.'"

  _dkexec robo test:suite "${PHPUNIT_TESTS}functional-javascript"

  _dkexec bash -c "cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional-javascript"
}

_nightwatch() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec bash -c "cp -u ${CI_PROJECT_DIR}/.gitlab-ci/.env.nightwatch ${WEB_ROOT}/core/.env"

  printf ">>> [NOTICE] Patching nightwatch for Drupal profile support.\\n"

  _dkexec bash -c "curl -fsSL https://www.drupal.org/files/issues/2019-02-05/3017176-7.patch -o ${DOC_ROOT}/3017176-7.patch"
  docker exec -it -w ${WEB_ROOT} ci-drupal bash -c "patch -N -p1 < ${DOC_ROOT}/3017176-7.patch"

  _dkexec bash -c "cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}"
  _dkexec robo prepare:folders

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${DOC_ROOT}

  docker exec -it -w ${WEB_ROOT}/core ci-drupal yarn install
  docker exec -it -w ${WEB_ROOT}/core ci-drupal yarn test:nightwatch ${NIGHTWATCH_TESTS}
}

_security_checker() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n\\n" "${_blu}" "${_end}"

  _build
  _dkexec bash -c "cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}"
  _dkexec robo prepare:folders
  _dkexec security-checker security:check
}

####### QA jobs

# Replicate cp in all qa / lint / metrics jobs
_cp_qa_lint_metrics() {
  # Place config files in a proper directory.
  printf ">>> [NOTICE] cp config to %s\\n" "${CI_PROJECT_DIR}"
  _dkexec bash -c "cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}/.gitlab-ci/.phpmd.xml ${CI_PROJECT_DIR}/.gitlab-ci/.phpqa.yml ${CI_PROJECT_DIR}/.gitlab-ci/.eslintignore ${CI_PROJECT_DIR}"
}

_code_quality() {
  printf "\\n%s[INFO]%s Perform job 'Code quality' (code_quality)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _dkexec robo prepare:folders

  _dkexec phpqa ${PHPQA_REPORT}/code_quality ${TOOLS} ${PHPQA_PHP_CODE}
}

_best_practices() {
  printf "\\n%s[INFO]%s Perform job 'Best practices' (best_practices)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml
  _dkexec robo prepare:folders

  _dkexec phpqa ${PHPQA_REPORT}/best_practices --tools ${BEST_PRACTICES} ${PHPQA_PHP_CODE}
}

####### Lint jobs

_eslint() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _dkexec robo prepare:folders

  # _dkexec eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json ${JS_CODE}
  _dkexec eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json --format html --output-file ${REPORT_DIR}/js-lint-report.html ${JS_CODE}
}

_stylelint() {
  printf "\\n%s[INFO]%s Perform job 'Css lint' (stylelint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _dkexec robo prepare:folders

  _dkexec stylelint --config-basedir /var/www/.node/node_modules/ \
    --config ${WEB_ROOT}/core/.stylelintrc.json -f verbose "${CSS_FILES}"
}

_sass_lint() {
  printf "\\n%s[INFO]%s Perform job 'Sass lint' (sass_lint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _dkexec robo prepare:folders

  printf ">>> [NOTICE] Install Sass-lint\\n"
  docker exec -it -w ${WEB_ROOT}/core ci-drupal npm install --no-audit git://github.com/sasstools/sass-lint.git#develop

  _dkexec ${WEB_ROOT}/core/node_modules/.bin/sass-lint --config ${SASS_CONFIG} --verbose --no-exit
  _dkexec ${WEB_ROOT}/core/node_modules/.bin/sass-lint --config ${SASS_CONFIG} --verbose --no-exit --format html --output ${REPORT_DIR}/sass-lint-report.html
}

####### Metrics jobs

_phpmetrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (phpmetrics)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _dkexec robo prepare:folder

  _dkexec phpqa ${PHPQA_REPORT}/phpmetrics --tools phpmetrics ${PHPQA_PHP_CODE}
}

_phpstat() {
  printf "\\n%s[INFO]%s Perform job 'Php stats' (phpstat)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _dkexec robo prepare:folders

  _dkexec phpqa ${PHPQA_REPORT}/phpstat --tools phploc,pdepend ${PHPQA_PHP_CODE}
}

###############################################################################
# Docker helpers commands.
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal "$@"
  fi
}

_dkexeca() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -u www-data -w ${CI_PROJECT_DIR} ci-drupal "$@"
  fi
}

###############################################################################
# Helpers commands.
###############################################################################

_reset_gitlab() {
  printf "\\n%s[INFO]%s Reset stack to mimic Gitlab-ci\\n" "${_blu}" "${_end}"
  _down
  _clean_config
  _clean_custom
  _up
}

_nuke() {
  printf "\\n%s[INFO]%s Full reset!\\n" "${_blu}" "${_end}"
  _down
  _clean_full
  rm -rf tmp
}

_up() {
  if [ -f "tests/docker-compose.yml" ]; then
    docker-compose -f tests/docker-compose.yml up -d
  else
    if [ -f "docker-compose.yml" ]; then
      docker-compose up -d
    else
      printf "%s[ERROR]%s Missing docker-compose.yml file.\\n" "${_red}" "${_end}"
      exit 1
    fi
  fi
  printf "[NOTICE] Please wait ~20s for DB to be initialized...\\n"
}

_down() {
  if [ -f "tests/docker-compose.yml" ]; then
    docker-compose -f tests/docker-compose.yml down
  else
    if [ -f "docker-compose.yml" ]; then
      docker-compose down
    else
      printf "%s[ERROR]%s Missing docker-compose.yml file.\\n" "${_red}" "${_end}"
      exit 1
    fi
  fi
}

_clean() {
  _clean_config
  rm -rf reports/*
}

_clean_config() {
  rm -f .env.nightwatch .eslintignore .phpmd.xml .phpqa.yml .sass-lint.yml phpunit.local.xml phpunit.xml RoboFile.php
}

_clean_full() {
  _clean
  if [ ${CI_TYPE} == 'custom' ];
  then
    _clean_custom
  fi
}

_clean_custom() {
  rm -rf tmp* drush scripts vendor \
    web/core web/sites web/profiles web/.* web/*.php web/robots.txt web/web.config \
    .editorconfig .env.example .gitattributes .travis.yml composer.* load.environment.php phpunit.xml.dist
}

_clean_unit() {
  _clean_config
  if [ ${CI_TYPE} == 'custom' ];
  then
    _clean_custom
  fi
}

###############################################################################
# Commands to reference group of commands.
###############################################################################

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
#   _main [<arguments>]
#
# Description:
#   Entry point for the program, handling basic option parsing and dispatching.
_main() {

  if [ "${_CMD}" == "help" ]; then
    _help
    exit 0
  fi

  # Run command if exist.
  __call="_${_CMD}"
  if [ "$(type -t "${__call}")" == 'function' ]; then
    $__call
  else
    _help
  fi
}

# Call `_main` after everything has been defined.
_main
