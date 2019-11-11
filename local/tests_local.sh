#!/bin/bash

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.

_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$_SOURCE" ]; do # resolve $_SOURCE until the file is no longer a symlink
  _DIR="$( cd -P "$( dirname "$_SOURCE" )" && pwd )"
  _SOURCE="$(readlink "$_SOURCE")"
  [[ $_SOURCE != /* ]] && _SOURCE="$_DIR/$_SOURCE" # if $_SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
_DIR="$( cd -P "$( dirname "$_SOURCE" )" && pwd )"

IFS=$'\n\t'

###############################################################################
# Environment
###############################################################################

# $_ME
#
# Set to the program's basename.
_ME=$(basename "${0}")

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
  all                 Run all tests!
  status              Give information and versions of tools.
  clean               Remove files and reports generated or copied by this script.

  Grouped tests:
    security          Run security tests (if any composer.json file).
    unit              Run unit tests + nightwatch + behat + pa11y.
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
    behat
    pa11y
    code_quality
    best_practices
    js_lint
    css_lint
    sass_lint
    phpmetrics
    phpstats

Options
  -h|--help                       Print help.
  -sp|--skip-prepare              Skip prepare step (copy files, set folders).
  -sb|--skip-build                Skip build step (cache, perform build).
  -si|--skip-install              Skip Drupal install step (behat).
  -sa|-spb|--skip-prepare-build   Skip bith previous.
  -sim|--simulate                 Robo simulate action.
  --clean                         Delete previous reports.
  --debug                         Debug this script.
  --debug-fail                    Debug this script, stop on any error.

HEREDOC
}

###############################################################################
# Die
###############################################################################

# _die()
#
# Usage:
#   _die printf "Error message. Variable: %s\n" "$0"
#
# A simple function for exiting with an error after executing the specified
# command. The command is expected to print a message and should typically
# be either `echo`, `printf`, or `cat`.
_die() {
  # Prefix die message with "cross mark (U+274C)", often displayed as a red x.
  printf "❌  "
  "${@}" 1>&2
  exit 1
}
# die()
#
# Usage:
#   die "Error message. Variable: $0"
#
# Exit with an error and print the specified message.
#
# This is a shortcut for the _die() function that simply echos the message.
die() {
  _die echo "${@}"
}

###############################################################################
# Debug
###############################################################################

# _debug()
#
# Usage:
#   _debug printf "Debug info. Variable: %s\n" "$0"
#
# A simple function for executing a specified command if the `$_USE_DEBUG`
# variable has been set. The command is expected to print a message and
# should typically be either `echo`, `printf`, or `cat`.
__DEBUG_COUNTER=0
_debug() {
  if [[ "${_USE_DEBUG:-"0"}" -eq 1 ]]
  then
    __DEBUG_COUNTER=$((__DEBUG_COUNTER+1))
    # Prefix debug message with "bug (U+1F41B)"
    printf "🐛  %s " "${__DEBUG_COUNTER}"
    "${@}"
    printf "――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――\\n"
  fi
}
# debug()
#
# Usage:
#   debug "Debug info. Variable: $0"
#
# Print the specified message if the `$_USE_DEBUG` variable has been set.
#
# This is a shortcut for the _debug() function that simply echos the message.
debug() {
  _debug echo "${@}"
}

# Program Options #############################################################

_red=$'\e[1;31m'
_grn=$'\e[1;32m'
_blu=$'\e[1;34m'
_end=$'\e[0m'

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0

# Initialize additional expected option variables.
__skip_prepare=0
__skip_build=0
__skip_install=0
__skip_all=0
__simulate=""
__clean=0
__drupal_profile="minimal"

_CMD=()

while [[ ${#} -gt 0 ]]
do
  __option="${1:-}"
  case "${__option}" in
    -h|--help)
      _PRINT_HELP=1
      shift
      ;;
    -sp|--skip-prepare)
      printf ">>> [NOTICE] skip prepare set\\n"
      __skip_prepare=1
      shift
      ;;
    -sb|--skip-build)
      printf ">>> [NOTICE] skip build set\\n"
      __skip_build=1
      shift
      ;;
    -si|--skip-install)
      printf ">>> [NOTICE] skip install set\\n"
      __skip_install=1
      shift
      ;;
    -sa|--skip-all)
      printf ">>> [NOTICE] skip all\\n"
      __skip_all=1
      shift
      ;;
    -sim|--simulate)
      printf ">>> [NOTICE] simulate robo\\n"
      __simulate="--simulate"
      __skip_all=1
      shift
      ;;
    --clean)
      printf ">>> [NOTICE] Clean flag\\n"
      __clean=1
      shift
      ;;
    --debug)
      printf ">>> [NOTICE] Debug mode on!\\n"
      _USE_DEBUG=1
      shift
      ;;
    --debug-fail)
      printf ">>> [NOTICE] Debug fail stop mode on!\\n"
      _USE_DEBUG=1
      trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR
      set -u -e -E -o pipefail
      shift
      ;;
    --endopts)
      # Terminate option parsing.
      break
      ;;
    -*)
      _die printf "Unexpected option: %s\\n" "${__option}"
      ;;
    *)
      _CMD+=("$1")
      shift
      ;;
  esac
done

_ARGS=${_CMD[@]:1}

###############################################################################
# Program Functions
###############################################################################

_status() {

  printf "CI_DRUPAL_VERSION: %s\\nCI_TYPE: %s\\nDOC_ROOT: %s\\nWEB_ROOT: %s\\nCI_PROJECT_DIR: %s\\nREPORT_DIR: %s\\n" \
  ${CI_DRUPAL_VERSION} ${CI_TYPE} ${DOC_ROOT} ${WEB_ROOT} ${CI_PROJECT_DIR} ${REPORT_DIR}
  printf "APACHE_RUN_USER: %s\\nAPACHE_RUN_GROUP: %s\\nPHPUNIT_TESTS: %s\\nBROWSERTEST_OUTPUT_DIRECTORY: %s\\n" \
  ${APACHE_RUN_USER} ${APACHE_RUN_GROUP} ${PHPUNIT_TESTS} ${BROWSERTEST_OUTPUT_DIRECTORY}

  _dkexec_bash /scripts/run-tests.sh
  sleep 2s

  docker exec -d ci-drupal bash -c "/scripts/start-selenium-standalone.sh"
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.sh"
  sleep 2s

  printf "Selenium running? (If nothing, no!)\\n"
  _dkexec_bash "curl -s http://localhost:4444/wd/hub/status | jq '.'"

  printf "Chrome running? (If nothing, no!)\\n"
  _dkexec_bash "curl -s http://localhost:9222/json/version | jq '.'"

  printf "\\n"
}

_st() {
  _status
}

# Replicate Gitlab-ci.yml .test_template
_tests_prepare() {
  if [ $__skip_prepare = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] tests_prepare\\n"
  else
    printf ">>> [NOTICE] tests_prepare\\n"

    _prepare_folders

    # Apache launch is entrypoint.
    # docker exec -d ci-drupal bash -c "apache2-foreground"

    # Prepare needed folders, reproduce .test_template
    _dkexec cp -u ${CI_PROJECT_DIR}/local/phpunit.local.xml ${WEB_ROOT}/core/phpunit.xml

    # RoboFile.php is already at root.
    _dkexec_docroot robo $__simulate ensure:tests-folders
  fi
}

# Replicate Build job.
_build() {
  _copy_robofile

  if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] build\\n"
  else
    printf ">>> [NOTICE] build\\n"

    # Extra local step, ensure composer permissions.
    # _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www/.composer /var/www/${REPORT_DIR}
    # _dkexec chmod -R 777 /var/www/.composer /var/www/${REPORT_DIR}

    _dkexec_docroot robo $__simulate project:build

    _dkexec_docroot robo $__simulate yarn:install

    _dkexec_docroot robo $__simulate install:phpunit

    _create_artifacts
  fi
}

_prepare_folders() {
  if [ $__skip_prepare = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] prepare_folders\\n"
  else
    _dkexec_docroot robo $__simulate prepare:folders
  fi
}

_create_artifacts() {
  if [ ${CI_TYPE} == "project" ]; then
    printf ">>> [NOTICE] Uploading artifacts...\\n"

    if ! [ -f ./tmp/artifacts.tgz ]
    then
      mkdir -p ./tmp
      _dkexec mkdir -p /tmp
      _dkexec tar -czf /tmp/artifacts.tgz \
        --exclude="${WEB_ROOT}/modules/custom" \
        --exclude="${WEB_ROOT}/themes/custom" \
        ${DOC_ROOT}/vendor ${DOC_ROOT}/web ${WEB_ROOT}/core/node_modules \
        ${DOC_ROOT}/drush ${DOC_ROOT}/scripts ${DOC_ROOT}/composer.json \
        ${DOC_ROOT}/composer.lock ${DOC_ROOT}/.env.example ${DOC_ROOT}/load.environment.php
      docker cp ci-drupal:/tmp/artifacts.tgz ./tmp/
    else
      printf ">>> [SKIP] Artifact already exist.\\n"
    fi
  fi
}

# Replicate Build job artifacts.
_extract_artifacts() {
  if [ ${CI_TYPE} == "project" ]; then
    if [ -f ./tmp/artifacts.tgz ]
    then
      printf ">>> [NOTICE] extract_artifacts..."
      _dkexec mv /tmp/artifacts.tgz ${DOC_ROOT}
      _dkexec tar -xzf ${DOC_ROOT}/artifacts.tgz
      _dkexec rm -f ${DOC_ROOT}/artifacts.tgz
      printf " Done!\\n"
    else
      printf ">>> [SKIP] No artifacts!\\n" "${_blu}" "${_end}"
    fi
  else
    printf ">>> [SKIP] Not a project, extract_artifacts skipped.\\n"
  fi
}

_copy_robofile() {
  printf ">>> [NOTICE] copy_robofile\\n"
  # _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${DOC_ROOT}
}

####### Tests jobs

_unit_kernel() {
  printf "\\n%s[INFO]%s Perform job 'Unit and kernel tests' (unit_kernel)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec_docroot robo $__simulate test:suite "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_code_coverage() {
  printf "\\n%s[INFO]%s Perform job 'Code coverage' (code_coverage)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec_docroot robo $__simulate test:coverage "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
  _dkexec cp -r ${WEB_ROOT}/${REPORT_DIR} ./

  # bash <(curl -s https://codecov.io/bash) -f ${REPORT_DIR}/coverage.xml -t ${CODECOV_TOKEN}
}

_functional() {
  printf "\\n%s[INFO]%s Perform job 'Functional' (functional)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  # Specific to run a local test as apache.
  # _dkexec touch "/var/www/${REPORT_DIR}/phpunit.html"
  # _dkexec mkdir -p "/var/www/${REPORT_DIR}/functional"
  # _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} "/var/www/${REPORT_DIR}"

  _dkexec_apache robo $__simulate test:suite ${PHPUNIT_TESTS}functional "null" "/var/www/${REPORT_DIR}"

  _copy_output ${PHPUNIT_TESTS}functional
}

_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  # Starting Chromedriver.
  docker exec -d ci-drupal /scripts/start-chromedriver.sh
  sleep 5s

  if [ ${_USE_DEBUG} == "1" ]; then
    # debug _dkexec_bash "curl -s http://localhost:4444/status | jq '.'"
    _dkexec_bash "curl -s http://localhost:4444/status | jq '.'"
    # _dkexec curl -d '{"desiredCapabilities":{"browserName":"chrome","name":"Behat Test","chromeOptions":{"w3c":false,"args":["--whitelisted-ips","--disable-gpu","--headless","--no-sandbox","--window-size=1920,1080"]}}}' -H "Content-Type: application/json" -X POST http://ci-chromedriver:4444/wd/hub/session >> /var/www/${REPORT_DIR}/webdriver.log
  fi

  _dkexec_apache robo $__simulate test:suite ${PHPUNIT_TESTS}functional-javascript "null" "/var/www/${REPORT_DIR}"

  _copy_output ${PHPUNIT_TESTS}functional-javascript
}

_nightwatch() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec curl -f -N ${CI_NIGHTWATCH_ENV} -o ${WEB_ROOT}/core/.env
  _dkexec cp -u ${CI_PROJECT_DIR}/.gitlab-ci/html-reporter.js ${WEB_ROOT}/core/html-reporter.js

  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] patch_nightwatch\\n"
  else
    _dkexec_docroot robo $__simulate patch:nightwatch https://www.drupal.org/files/issues/2019-11-11/3017176-16.patch
  fi

  _dkexec_docroot robo $__simulate yarn:install

  _dkexec_docroot robo $__simulate test:nightwatch
}

_security_checker() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n\\n" "${_blu}" "${_end}"

  _build

  _prepare_folders

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/security \
    --tools security-checker:0 \
    --analyzedDirs ${DOC_ROOT} \
    --verbose
}

_behat() {
  printf "\\n%s[INFO]%s Perform job 'Behat' (behat)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _prepare_folders

  _PROFILE=$(yq r $_DIR/../.gitlab-ci.yml "[Behat tests].variables.DRUPAL_INSTALL_PROFILE")
  _install_drupal_robo $_PROFILE

  # Starting Chrome.
  _ensure_chrome
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.sh"
  sleep 5s

  if [ ${_USE_DEBUG} == "1" ]; then
    debug _dkexec_bash "curl -s http://localhost:9222/json/version | jq '.'"
  fi

  _dkexec_docroot robo $__simulate install:behat

  _dkexec_docroot robo $__simulate test:behat "${CI_PROJECT_DIR}/${REPORT_DIR}"
}

_pa11y() {
  printf "\\n%s[INFO]%s Perform job 'Pa11y' (pa11y)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _prepare_folders

  _PROFILE=$(yq r $_DIR/../.gitlab-ci.yml "[Pa11y].variables.DRUPAL_INSTALL_PROFILE")
  _install_drupal_robo $_PROFILE

  _dkexec_docroot robo $__simulate install:pa11y
  _dkexec_docroot robo $__simulate test:pa11y

  _dkexec_bash "cp -f ${CI_PROJECT_DIR}/pa11y*.png ${CI_PROJECT_DIR}/${REPORT_DIR}/"
}

####### QA jobs

# Replicate cp in all qa / lint / metrics jobs
_cp_qa_lint_metrics() {
  # Place config files in a proper directory.
  printf ">>> [NOTICE] cp config\\n"
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/.phpmd.xml ${CI_PROJECT_DIR}/.gitlab-ci/.phpqa.yml ${CI_PROJECT_DIR}/.gitlab-ci/.eslintignore ${CI_PROJECT_DIR}
}

_clean_qa_lint_metrics() {
  printf ">>> [NOTICE] clean config\\n"
  _dkexec rm -f ${CI_PROJECT_DIR}/.phpmd.xml ${CI_PROJECT_DIR}/.phpqa.yml ${CI_PROJECT_DIR}/.eslintignore
}

_code_quality() {
  printf "\\n%s[INFO]%s Perform job 'Code quality' (code_quality)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexec phpqa --buildDir ${REPORT_DIR}/code_quality --tools ${TOOLS} --analyzedDirs ${PHP_CODE_QA}

  _clean_qa_lint_metrics
}

_best_practices() {
  printf "\\n%s[INFO]%s Perform job 'Best practices' (best_practices)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml
  _prepare_folders

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/best_practices \
    --tools ${BEST_PRACTICES} \
    --analyzedDirs ${PHP_CODE_QA}

  _clean_qa_lint_metrics
}

####### Lint jobs

_eslint() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexec mkdir -p ${DOC_ROOT}/core

  _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.eslintrc.json -o ${WEB_ROOT}/core/.eslintrc.json

  _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.eslintrc.passing.json -o ${WEB_ROOT}/core/.eslintrc.passing.json

  _dkexec_bash "${WEB_ROOT}/core/node_modules/.bin/eslint \
    --config ${WEB_ROOT}/core/.eslintrc.passing.json \
    --format html \
    --output-file ${REPORT_DIR}/js-lint-report.html \
    ${JS_CODE}"

  _clean_qa_lint_metrics
}

_js_lint() {
  _eslint
}

_stylelint() {
  printf "\\n%s[INFO]%s Perform job 'Css lint' (stylelint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexec mkdir -p ${DOC_ROOT}/core
  _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.stylelintrc.json -o ${WEB_ROOT}/core/.stylelintrc.json

  # printf ">>> [NOTICE] Install Stylelint-formatter-pretty\\n"
  # _dkexec_docroot robo $__simulate install:stylelint-formatter-pretty

  # _dkexec_bash "stylelint --config-basedir ${WEB_ROOT}/core/node_modules/ \
  #   --custom-formatter ${WEB_ROOT}/core/node_modules/stylelint-formatter-pretty \
  #   --config ${WEB_ROOT}/core/.stylelintrc.json \${CSS_FILES}"

  _dkexec_bash "${WEB_ROOT}/core/node_modules/.bin/stylelint \
      --config-basedir ${WEB_ROOT}/core/node_modules/ \
      --config ${WEB_ROOT}/core/.stylelintrc.json \
      --formatter verbose \
      ${CSS_FILES}"

  _clean_qa_lint_metrics
}

_css_lint() {
  _stylelint
}

_sass_lint() {
  printf "\\n%s[INFO]%s Perform job 'Sass lint' (sass_lint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  printf ">>> [NOTICE] Install Sass-lint\\n"
  _dkexec_docroot robo $__simulate yarn add git://github.com/sasstools/sass-lint.git#develop

  _dkexec_bash "${WEB_ROOT}/core/node_modules/.bin/sass-lint \
    --config ${CI_PROJECT_DIR}/.gitlab-ci/.sass-lint.yml \
    --verbose \
    --no-exit \
    --format html \
    --output ${REPORT_DIR}/sass-lint-report.html"

  _clean_qa_lint_metrics
}

####### Metrics jobs

_phpmetrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (phpmetrics)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/phpmetrics \
    --tools phpmetrics \
    --analyzedDirs ${PHP_CODE_METRICS}

  _clean_qa_lint_metrics
}

_phpstats() {
  printf "\\n%s[INFO]%s Perform job 'Php stats' (phpstats)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/phpstats \
    --tools phploc,pdepend \
    --analyzedDirs ${PHP_CODE_METRICS}

  _clean_qa_lint_metrics
}

###############################################################################
# Docker helpers commands.
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal "$@" || true
  fi
}

_dkexec_docroot() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${DOC_ROOT} ci-drupal "$@" || true
  fi
}

_dkexec_apache() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${DOC_ROOT} -u www-data ci-drupal "$@" || true
  fi
}

_dkexec_background() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -d -w ${CI_PROJECT_DIR} ci-drupal "$@" || true
  fi
}

_dkexec_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
  fi
}

###############################################################################
# Helpers commands.
###############################################################################

_test_site() {
  if [ ${_ARGS} == "install" ]; then
    docker exec -it -w ${DOC_ROOT}/core ci-drupal bash -c "sudo -u www-data php ./scripts/test-site.php install --setup-file 'core/tests/Drupal/TestSite/TestSiteInstallTestScript.php' --install-profile 'demo_umami' --base-url http://localhost --db-url mysql://root@mariadb/drupal"
  else
    docker exec -it -w ${DOC_ROOT}/core ci-drupal bash -c "sudo -u www-data php ./scripts/test-site.php ${_ARGS}"
  fi
}

_install_drupal() {
  printf "\\n%s[INFO]%s Install Drupal\\n\\n" "${_blu}" "${_end}"

  _build
  _prepare_folders

  _install_drupal_robo ${1:'minimal'}
}

_install_drupal_robo() {
  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] install\\n"
  else
    printf ">>> [NOTICE] install Drupal %s\\n" "${1}"
    _dkexec_docroot robo $__simulate install:drupal ${1}
  fi
}

_set_dev_mode() {
  printf "\\n%s[INFO]%s Set dev mode\\n\\n" "${_blu}" "${_end}"

  _build
  _prepare_folders

  _dkexec_apache composer require drupal/console drupal/devel drupal/devel_php
  _dkexec_docroot ${DOC_ROOT}/vendor/bin/drupal site:mode dev

}

_init_variables() {
  __yaml="$_DIR/../.gitlab-ci.yml"
  __yaml_variables="$_DIR/../.gitlab-ci/.gitlab-ci-variables.yml"

  VERBOSE=$(yq r $__yaml_variables variables.VERBOSE)
  CI_TYPE=$(yq r $__yaml_variables variables.CI_TYPE)
  CI_IMAGE_VARIANT=$(yq r $__yaml_variables variables.CI_IMAGE_VARIANT)
  WEB_ROOT=$(yq r $__yaml_variables variables.WEB_ROOT)
  DOC_ROOT=$(yq r $__yaml_variables variables.DOC_ROOT)
  REPORT_DIR=$(yq r $__yaml_variables variables.REPORT_DIR)
  PHPUNIT_TESTS=$(yq r $__yaml_variables variables.PHPUNIT_TESTS)
  PHP_CODE=$(yq r $__yaml_variables variables.PHP_CODE)
  TOOLS=$(yq r $__yaml_variables variables.TOOLS)
  BEST_PRACTICES=$(yq r $__yaml_variables variables.BEST_PRACTICES)
  NIGHTWATCH_TESTS=$(yq r $__yaml_variables variables.NIGHTWATCH_TESTS)
  JS_CODE=$(yq r $__yaml_variables variables.JS_CODE)
  CSS_FILES=$(yq r $__yaml_variables variables.CSS_FILES)
  CI_NIGHTWATCH_ENV=$(yq r $__yaml_variables variables.CI_NIGHTWATCH_ENV)

  DRUPAL_SETUP_FROM_CONFIG=$(yq r $__yaml [.test_variables].DRUPAL_SETUP_FROM_CONFIG)
  APACHE_RUN_USER=$(yq r $__yaml [.test_variables].APACHE_RUN_USER)
  APACHE_RUN_GROUP=$(yq r $__yaml [.test_variables].APACHE_RUN_GROUP)
  BROWSERTEST_OUTPUT_DIRECTORY=$(yq r $__yaml [.test_variables].BROWSERTEST_OUTPUT_DIRECTORY)
  BROWSERTEST_OUTPUT_DIRECTORY=$(echo $BROWSERTEST_OUTPUT_DIRECTORY | sed "s#\${WEB_ROOT}#${WEB_ROOT}#g")
  DRUPAL_INSTALL_PROFILE="standard"

  if [ -f "$_DIR/.env" ]; then
    head -n 9 $_DIR/.env > $_DIR/.env.tmp
    source $_DIR/.env.tmp
    rm -f $_DIR/.env.tmp
  fi
}

_init() {
  _init_variables
}

_init_stack() {
  if [ ! "$(docker ps -q -f name=ci-drupal)" ]; then
      if [ "$(docker ps -aq -f status=exited -f name=ci-drupal)" ]; then
        # cleanup
        _down
      fi
      _up
      # Wait for Mariadb to be ready.
      sleep 20s
  fi
}

_generate_env_from_yaml() {
  printf "[NOTICE] Generate .env file..."
  _init_variables

  if ! [ -x "$(command -v yq)" ]; then
    curl -fsSL https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
  fi

  if ! [ -f "$_DIR/../.gitlab-ci.yml" ]; then
    printf "%s[ERROR]%s Missing .gitlab-ci.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi

  if ! [ -f "$_DIR/../.gitlab-ci/.gitlab-ci-variables.yml" ]; then
    printf "%s[ERROR]%s Missing .gitlab-ci-variables.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi

  __yaml="$_DIR/../.gitlab-ci.yml"
  __yaml_variables="$_DIR/../.gitlab-ci/.gitlab-ci-variables.yml"
  __env="$_DIR/.env"

  if [ -f $__env ]; then
    rm -f $__env
  fi

  touch $__env
  echo 'CI_PROJECT_NAME: my-project' >> $__env
  echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}" >> $__env

  yq r $__yaml_variables variables >> $__env
  yq r $__yaml "[.test_variables]" >> $__env

  CHROME_OPTS=$(yq r $__yaml "[Behat tests].variables.CHROME_OPTS")
  echo 'CHROME_OPTS='"${CHROME_OPTS}"'' >> $__env
  # Fix BEHAT_PARAMS, remove spaces and escape \.
  BEHAT_PARAMS=$(yq r $__yaml "[Behat tests].variables.BEHAT_PARAMS")
  BEHAT_PARAMS="$(echo -e "${BEHAT_PARAMS}" | tr -d '[:space:]')"
  BEHAT_PARAMS=$(sed 's#\\#\\\\#g' <<< $BEHAT_PARAMS)
  echo 'BEHAT_PARAMS='${BEHAT_PARAMS} >> $__env

  sed -i "s#\${CI_PROJECT_DIR}#${CI_PROJECT_DIR}#g" $__env
  sed -i "s#\${REPORT_DIR}#${REPORT_DIR}#g" $__env
  sed -i "s#\${PHP_CODE}#${PHP_CODE}#g" $__env

  sed -i 's#: #=#g' $__env
  # Remove empty values.
  sed -i 's#""##g' $__env
  # Treat 1 / 0 options without double quotes.
  sed -i 's#"1"#1#g' $__env
  sed -i 's#"0"#0#g' $__env
  # Remove quotes on CI_DRUPAL_VERSION.
  sed -i 's#CI_DRUPAL_VERSION="8\(.*\)"#CI_DRUPAL_VERSION=8\1#g' $__env

  # Remove single quotes
  sed -i "s#'##g" $__env
  # Fix selenium local access
  sed -i 's#http://localhost:4444#http://ci-chromedriver:4444#g' $__env

  sed -i "s#\${WEB_ROOT}#${WEB_ROOT}#g" $__env

  printf ">>> %s ... Done!\\n" $__env
}

_env() {
  _generate_env_from_yaml
}

_gen() {
  _generate_env_from_yaml
}

_ensure_chrome() {
  _test_chrome=$(docker exec -t ci-drupal sh -c "[ -f /usr/bin/google-chrome ] && echo true")
  if [ -z "${_test_chrome}" ]; then
    printf "%s[ERROR]%s Missing Google Chrome!\\n" "${_red}" "${_end}"
    exit 1
  fi
  docker exec -t ci-drupal google-chrome --version
}

_reset() {
  printf "\\n%s[INFO]%s Reset stack to mimic Gitlab-ci\\n" "${_blu}" "${_end}"
  _down
  _clean_config
  _up
}

_restart() {
  _down
  _clean_config
  sudo rm -rf reports/*
  _up
}

_nuke() {
  printf "\\n%s[INFO]%s Full reset!\\n" "${_blu}" "${_end}"
  _down
  sudo chown -R 1000:1000 ../
  sudo rm -rf tmp
  sudo rm -rf dump
  _clean_full
}

_up() {
  if ! [ -f "$_DIR/.env" ]; then
    printf "[NOTICE] Generate .env file for %s-%s\\n"  "${CI_DRUPAL_VERSION}" "${CI_IMAGE_VARIANT}"
    _generate_env_from_yaml
  fi

  if [ -f "$_DIR/docker-compose.yml" ]; then
    docker-compose --project-directory $_DIR -f $_DIR/docker-compose.yml up -d
  else
    printf "%s[ERROR]%s Missing $_DIR/docker-compose.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
  printf "[NOTICE] Please wait ~20s for DB to be initialized...\\n"
}

_down() {
  if [ -f "$_DIR/docker-compose.yml" ]; then
    docker-compose --project-directory $_DIR -f $_DIR/docker-compose.yml down
  else
    printf "%s[ERROR]%s Missing $_DIR/docker-compose.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
}

_copy_output() {
  _dkexec_background cp -r ${WEB_ROOT}/sites/simpletest/browser_output/ ${REPORT_DIR}/${1}
  sleep 1s
  _dkexec_bash "rm -rf ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output/*"
}

_clean() {
  _clean_browser_output
  _clean_config
  if [ -f "tmp/cache.tgz" ]; then
    rm -f tmp/cache.tgz
  fi
  sudo rm -rf reports/*
}

_clean_project() {
  _clean_config
  if [ -f "tmp/cache.tgz" ]; then
    rm -f tmp/cache.tgz
  fi
  sudo rm -rf reports/*
  sudo rm -rf .editorconfig .gitattributes composer.lock console/
  sudo composer run-script nuke
  rm -f /tmp/*.tgz
  sudo git clean -fd
  git checkout -- composer.json
}

_clean_browser_output() {
  # sudo rm -rf reports/**/browser_output
  _dkexec rm -rf ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output
  _dkexec mkdir -p ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output
  _dkexec chmod -R g+s ${BROWSERTEST_OUTPUT_DIRECTORY}
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${BROWSERTEST_OUTPUT_DIRECTORY}
}

_clean_config() {
  rm -f .env.nightwatch .eslintignore .phpmd.xml .phpqa.yml .sass-lint.yml phpunit.local.xml phpunit.xml RoboFile.php
}

###############################################################################
# Commands to reference group of commands.
###############################################################################

_all() {
  _security_checker
  _unit
  _qa
  _lint
  _metrics
}

_security() {
  _security_checker
}

_unit() {
  _unit_kernel
  # Can skip build and prepare for next items.
  __skip_build=1
  __skip_prepare=1
  _code_coverage
  _functional
  _functional_js
  _nightwatch
  _behat
  _pa11y
  __skip_build=0
  __skip_prepare=0
}

_lint() {
  _eslint
  __skip_prepare=1
  _stylelint
  _sass_lint
  __skip_prepare=0
}

_qa() {
  _code_quality
  __skip_prepare=1
  _best_practices
  __skip_prepare=0
}

_metrics() {
  _phpmetrics
  __skip_prepare=1
  _phpstats
  __skip_prepare=0
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

  if ((_PRINT_HELP))
  then
    _help
    exit 0
  elif [ "${_CMD}" == "init_variables" ]; then
    _init_variables
    exit 0
  elif [ "${_CMD}" == "generate_env_from_yaml" ]; then
    _generate_env_from_yaml
    exit 0
  fi

  # Run command if exist.
  __call="_${_CMD}"
  if [ "$(type -t "${__call}")" == 'function' ]; then
    _init_variables
    _init_stack
    $__call
  else
    printf "%s[ERROR]%s Unknown command: %s\\nRun --help for usage.\\n" "${_red}" "${_end}" "${_CMD}"
  fi
}

# Call `_main` after everything has been defined.
_main
