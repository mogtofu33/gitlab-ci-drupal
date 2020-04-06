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
  -sa|-skip-all                   Skip build, prepare and install.
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
_blu=$'\e[1;34m'
_dim=$'\e[2;37m'
_dim_blu=$'\e[2;34m'
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
      printf "%s[NOTICE]%s skip prepare set\\n" "${_dim}" "${_end}"
      __skip_prepare=1
      shift
      ;;
    -sb|--skip-build)
      printf "%s[NOTICE]%s skip build set\\n" "${_dim}" "${_end}"
      __skip_build=1
      shift
      ;;
    -si|--skip-install)
      printf "%s[NOTICE]%s skip install set\\n" "${_dim}" "${_end}"
      __skip_install=1
      shift
      ;;
    -sa|--skip-all)
      printf "%s[NOTICE]%s skip all set (build, prepare, install)\\n" "${_dim}" "${_end}"
      __skip_all=1
      shift
      ;;
    -sim|--simulate)
      printf "%s[NOTICE]%s simulate robo\\n" "${_dim}" "${_end}"
      __simulate="--simulate"
      __skip_all=1
      shift
      ;;
    --clean)
      printf "%s[NOTICE]%s Clean flag\\n" "${_dim}" "${_end}"
      __clean=1
      shift
      ;;
    --debug)
      printf "%s[NOTICE]%s Debug mode on!\\n" "${_dim}" "${_end}"
      _USE_DEBUG=1
      shift
      ;;
    --debug-fail)
      printf "%s[NOTICE]%s Debug fail stop mode on!\\n" "${_dim}" "${_end}"
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

  # docker exec -d ci-drupal bash -c "/scripts/start-selenium-standalone.sh"
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.sh"
  sleep 2s

  # printf "Selenium running? (If nothing, no!)\\n"
  _dkexec_bash "curl -s http://localhost:4444/wd/hub/status | jq '.'"

  printf "Chrome running? (If nothing, no!)\\n"
  _dkexec_bash "curl -s http://localhost:9222/json/version | jq '.'"

  printf "\\n"
}

_st() {
  _status
}

# Replicate Gitlab-ci.yml .test_template
_test_template() {
  if [ $__skip_prepare = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s test_template\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s Replicate .test_template\\n" "${_dim}" "${_end}"

    _prepare_folders

    if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
      printf "%s[SKIP]%s build (require:drupal-dev) \\n" "${_dim_blu}" "${_end}"
    else
      _dkexec_robo require:drupal-dev
    fi

    # Apache launch is entrypoint.
    # docker exec -d ci-drupal bash -c "apache2-foreground"

    # Prepare needed folders, reproduce .test_template
    _dkexec cp -f ${CI_PROJECT_DIR}/.gitlab-ci/phpunit.xml ${WEB_ROOT}/core/phpunit.xml
    if [ -f $_DIR/../.gitlab-ci/phpunit.xml.${PHPUNIT_TESTS} ]; then
      _dkexec cp -u  ${CI_PROJECT_DIR}/.gitlab-ci/phpunit.xml.${PHPUNIT_TESTS} ${WEB_ROOT}/core/phpunit.xml
    fi

    # RoboFile.php is already at root.
    _dkexec_robo ensure:tests-folders
  fi
}

# Replicate Build job.
_build() {

  if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s build\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s replicate build\\n" "${_dim}" "${_end}"

    _dkexec_robo project:build

    _create_artifacts
  fi
}

_prepare_folders() {
  printf "%s[NOTICE]%s prepare_folders\\n" "${_dim}" "${_end}"
  if [ $__skip_prepare = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s prepare_folders\\n" "${_dim_blu}" "${_end}"
  else
    _dkexec_robo prepare:folders

    # Extra local step, ensure composer permissions.
    _dkexec chown -R "${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" /var/www/.composer "${CI_PROJECT_DIR}/${REPORT_DIR}" "${REPORT_DIR}"
    _dkexec chmod -R 777 /var/www/.composer "${CI_PROJECT_DIR}/${REPORT_DIR}" "${REPORT_DIR}"
  fi
  printf "...Done!\\n"
}

_create_artifacts() {
  if [ ${CI_TYPE} == "project" ]; then
    printf "%s[NOTICE]%s Uploading artifacts...\\n" "${_dim}" "${_end}"

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
      printf "%s[SKIP]%s Artifact already exist.\\n" "${_dim_blu}" "${_end}"
    fi
  fi
}

# Replicate Build job artifacts.
_extract_artifacts() {
  if [ ${CI_TYPE} == "project" ]; then
    if [ -f ./tmp/artifacts.tgz ]
    then
      printf "%s[NOTICE]%s replicate extract_artifacts..." "${_dim}" "${_end}"
      _dkexec mv /tmp/artifacts.tgz ${DOC_ROOT}
      _dkexec tar -xzf ${DOC_ROOT}/artifacts.tgz
      _dkexec rm -f ${DOC_ROOT}/artifacts.tgz
      printf " Done!\\n"
    else
      printf "%s[SKIP]%s No artifacts!\\n" "${_dim_blu}" "${_end}"
    fi
  else
    printf "%s[SKIP]%s Not a project, extract_artifacts skipped.\\n" "${_dim_blu}" "${_end}"
  fi
}

_copy_robofile() {
  printf "%s[NOTICE]%s copy_robofile" "${_dim}" "${_end}"
  # _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${DOC_ROOT}
  printf "...Done!\\n"
}

####### Tests jobs

_unit_kernel() {
  printf "\\n%s[INFO]%s Perform job 'Unit and kernel tests' (unit_kernel)\\n\\n" "${_blu}" "${_end}"

  _build
  _test_template

  _dkexec_robo test:suite "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_code_coverage() {
  printf "\\n%s[INFO]%s Perform job 'Code coverage' (code_coverage)\\n\\n" "${_blu}" "${_end}"

  _build
  _test_template

  _dkexec_robo test:coverage "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
  # _dkexec cp -r ${WEB_ROOT}/${REPORT_DIR} ./

  # bash <(curl -s https://codecov.io/bash) -f ${REPORT_DIR}/coverage.xml -t ${CODECOV_TOKEN}
}

_pre_functional() {
  _build
  _test_template

  # Specific to run a local test as apache.
  _dkexec mkdir -p "${CI_PROJECT_DIR}/${REPORT_DIR}/functional"
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} "${CI_PROJECT_DIR}/${REPORT_DIR}"
}

_functional() {
  printf "\\n%s[INFO]%s Perform job 'Functional' (functional)\\n\\n" "${_blu}" "${_end}"
  _pre_functional
  _functional_cmd
  _post_functional
}

_functional_cmd() {
  _dkexec_apache robo $__simulate test:suite ${PHPUNIT_TESTS}functional "null" "${CI_PROJECT_DIR}/${REPORT_DIR}"
}

_post_functional() {
  _copy_output ${PHPUNIT_TESTS}functional
}

_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n\\n" "${_blu}" "${_end}"

  _build
  _test_template

  # Starting Chromedriver.
  docker exec -d ci-drupal /scripts/start-chromedriver.sh
  sleep 5s

  if ((_USE_DEBUG)); then
    debug _dkexec_bash "curl -s http://localhost:9515/status | jq '.'"
  fi

  _dkexec_apache robo $__simulate test:suite ${PHPUNIT_TESTS}functional-javascript "null" "${CI_PROJECT_DIR}/${REPORT_DIR}"

  _copy_output ${PHPUNIT_TESTS}functional-javascript
}

_nightwatch() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n\\n" "${_blu}" "${_end}"

  _build
  _test_template

  _dkexec curl -f -N ${CI_NIGHTWATCH_ENV} -o ${WEB_ROOT}/core/.env
  _dkexec cp -u ${CI_PROJECT_DIR}/.gitlab-ci/html-reporter.js ${WEB_ROOT}/core/html-reporter.js

  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s patch_nightwatch\\n" "${_dim_blu}" "${_end}"
  else
    if [ ${CI_DRUPAL_VERSION} == "8.7" ]; then
      _dkexec_robo patch:nightwatch https://www.drupal.org/files/issues/2019-09-06/3017176-12.patch;
    else
      _dkexec_robo  patch:nightwatch https://www.drupal.org/files/issues/2019-11-11/3017176-16.patch;
    fi
  fi

  if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s build (yarn:install) \\n" "${_dim_blu}" "${_end}"
  else
    _dkexec_robo  yarn:install
  fi

  _dkexec_robo  test:nightwatch
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
  _test_template

  _prepare_folders

  _install_drupal_robo ${DRUPAL_INSTALL_PROFILE}

  # Starting Chrome.
  _ensure_chrome
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.sh"
  sleep 5s

  if ((_USE_DEBUG)); then
    debug _dkexec_bash "curl -s http://localhost:9222/json/version | jq '.'"
  fi

  _dkexec_robo  install:behat

  _dkexec_robo  test:behat "${CI_PROJECT_DIR}/${REPORT_DIR}/behat"
}

_pa11y() {
  printf "\\n%s[INFO]%s Perform job 'Pa11y' (pa11y)\\n\\n" "${_blu}" "${_end}"

  _build
  _test_template

  _prepare_folders

  _install_drupal_robo ${DRUPAL_INSTALL_PROFILE}

  _dkexec_robo  install:pa11y
  _dkexec_robo  test:pa11y

  _dkexec_bash "mkdir -p ${REPORT_DIR}/pa11y"
  _dkexec_bash "cp -f ${CI_PROJECT_DIR}/pa11y*.png ${REPORT_DIR}/pa11y"
}

####### QA jobs

# Replicate cp in all qa / lint / metrics jobs
_cp_qa_lint_metrics() {
  # Place config files in a proper directory.
  printf "%s[NOTICE]%s cp config" "${_dim}" "${_end}"
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/.phpmd.xml ${CI_PROJECT_DIR}/.gitlab-ci/.phpqa.yml ${CI_PROJECT_DIR}/.gitlab-ci/.eslintignore ${CI_PROJECT_DIR}
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/.eslintignore ${WEB_ROOT}/core
  _dkexec chmod 755 ${CI_PROJECT_DIR}
  printf "...Done!\\n"
}

_clean_qa_lint_metrics() {
  printf "%s[NOTICE]%s clean config\\n" "${_dim}" "${_end}"
  _dkexec rm -f ${CI_PROJECT_DIR}/.phpmd.xml ${CI_PROJECT_DIR}/.phpqa.yml ${CI_PROJECT_DIR}/.eslintignore
}

_code_quality() {
  printf "\\n%s[INFO]%s Perform job 'Code quality' (code_quality)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics

  _prepare_folders
  _dkexec_robo  install:coder

  _dkexec phpqa --buildDir ${REPORT_DIR}/code_quality --tools ${TOOLS} --analyzedDirs ${PHP_CODE_QA}

  _clean_qa_lint_metrics
}

_best_practices() {
  printf "\\n%s[INFO]%s Perform job 'Best practices' (best_practices)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics

  sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml

  _prepare_folders
  _dkexec_robo  install:coder

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/best_practices \
    --tools ${BEST_PRACTICES} \
    --analyzedDirs ${PHP_CODE_QA}

  _clean_qa_lint_metrics
}

####### Lint jobs

_lint_template() {

  _cp_qa_lint_metrics
  _prepare_folders

  # Install packages from core/package.json
  if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s build (yarn:install) \\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s yarn:install\\n" "${_dim}" "${_end}"
    _dkexec_robo  yarn:install
    printf "...done!\\n"
  fi
}

_eslint() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n\\n" "${_blu}" "${_end}"
  _lint_template

  # _dkexec mkdir -p ${DOC_ROOT}/core

  # _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.eslintrc.json -o ${WEB_ROOT}/core/.eslintrc.json

  # _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.eslintrc.passing.json -o ${WEB_ROOT}/core/.eslintrc.passing.json

  _dkexec_core_bash "${WEB_ROOT}/core/node_modules/.bin/eslint \
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
_lint_template

  # _dkexec mkdir -p ${DOC_ROOT}/core
  # _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.stylelintrc.json -o ${WEB_ROOT}/core/.stylelintrc.json

  # printf "%s[NOTICE]%s Install Stylelint-formatter-pretty\\n" "${_dim}" "${_end}"
  # _dkexec_robo  install:stylelint-formatter-pretty

  # _dkexec_core_bash "${WEB_ROOT}/core/node_modules/.bin/stylelint\
  #   --config-basedir ${WEB_ROOT}/core/node_modules/ \
  #   --custom-formatter ${WEB_ROOT}/core/node_modules/stylelint-formatter-pretty \
  #   --config ${WEB_ROOT}/core/.stylelintrc.json \${CSS_FILES}"

  _dkexec_core_bash "${WEB_ROOT}/core/node_modules/.bin/stylelint \
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
  _lint_template

  printf "%s[NOTICE]%s Install Sass-lint\\n" "${_dim}" "${_end}"
  if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s build (yarn add sass-lint.git) \\n" "${_dim_blu}" "${_end}"
  else
    _dkexec_robo  yarn add git://github.com/sasstools/sass-lint.git#develop
  fi

  _dkexec_core_bash "${WEB_ROOT}/core/node_modules/.bin/sass-lint \
    --config ${CI_PROJECT_DIR}/.gitlab-ci/.sass-lint.yml \
    --verbose \
    --no-exit \
    --format html \
    --output ${REPORT_DIR}/sass-lint-report.html"

  _clean_qa_lint_metrics
}

####### Metrics jobs

_metrics_template() {
  _cp_qa_lint_metrics
  _prepare_folders
}

_phpmetrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (phpmetrics)\\n\\n" "${_blu}" "${_end}"
  _metrics_template

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/phpmetrics \
    --tools phpmetrics \
    --analyzedDirs '${PHP_CODE_METRICS}'

  _clean_qa_lint_metrics
}

_phpstats() {
  printf "\\n%s[INFO]%s Perform job 'Php stats' (phpstats)\\n\\n" "${_blu}" "${_end}"
  _metrics_template

  _dkexec phpqa \
    --buildDir ${REPORT_DIR}/phpstats \
    --tools phploc,pdepend \
    --analyzedDirs '${PHP_CODE_METRICS}'

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

_dkexec_robo() {
  _copy_robofile
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${DOC_ROOT} ci-drupal robo $__simulate "$@" || true
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

_dkexec_core_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${DOC_ROOT}/web/core ci-drupal bash -c "$@"
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

  _install_drupal_robo ${_ARGS:-'minimal'}
}

_install_drupal_robo() {
  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf "%s[SKIP]%s install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Drupal %s\\n"  "${_dim}" "${_end}" "${1}"
    _dkexec_robo install:drupal ${1}
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
  _generate_env_from_yaml

  source $__env

  # CHROME_OPTS needs no quotes so cannot be sourced.
  CHROME_OPTS=$(yq r $__yaml "[Behat tests].variables.CHROME_OPTS")
  echo "CHROME_OPTS=${CHROME_OPTS}" >> $__env

  # Remove quotes on NIGHTWATCH_TESTS.
  sed -i 's#NIGHTWATCH_TESTS="\(.*\)"#NIGHTWATCH_TESTS=\1#g' $__env
}

_init_stack() {
  if [ ! "$(docker ps -q -f name=ci-drupal)" ]; then
      if [ "$(docker ps -aq -f status=exited -f name=ci-drupal)" ]; then
        # cleanup
        _down
      fi
      _up
      # Wait for Mariadb to be ready.
      sleep 10s
  fi
}

_generate_env_from_yaml() {

  __yaml="$_DIR/../.gitlab-ci.yml"
  __yaml_variables="$_DIR/../.gitlab-ci/.gitlab-ci-variables.yml"
  __yaml_local="$_DIR/.local.yml"
  __env="$_DIR/.env"

  _check_yq

  debug "%s[NOTICE]%s Generate .env file..." "${_dim}" "${_end}"

  WEB_ROOT=$(yq r $__yaml_variables "variables.WEB_ROOT")
  CI_PROJECT_DIR="/builds"
  REPORT_DIR=$(yq r $__yaml_variables "variables.REPORT_DIR")

  if [ -f $__env ]; then
    rm -f $__env
  fi

  touch $__env

  echo '# This file is auto generated, do not edit.' >> $__env

  echo 'CI_PROJECT_NAME: my-project' >> $__env
  echo "CI_PROJECT_DIR: /builds" >> $__env

  yq r $__yaml_variables variables >> $__env
  yq r $__yaml "[.test_variables]" >> $__env

  # Fix BEHAT_PARAMS, remove spaces and escape \.
  BEHAT_PARAMS=$(yq r $__yaml "[Behat tests].variables.BEHAT_PARAMS")
  BEHAT_PARAMS="$(echo -e "${BEHAT_PARAMS}" | tr -d '[:space:]')"
  BEHAT_PARAMS=$(sed 's#\\#\\\\#g' <<< $BEHAT_PARAMS)
  echo 'BEHAT_PARAMS='${BEHAT_PARAMS} >> $__env

  # Fix MINK_DRIVER_ARGS_WEBDRIVER, remove spaces and escape \.
  sed -i '/MINK_DRIVER_ARGS_WEBDRIVER/d' $__env
  sed -i '/^ /d' $__env
  MINK_DRIVER_ARGS_WEBDRIVER=$(yq r $__yaml "[.test_variables].MINK_DRIVER_ARGS_WEBDRIVER")
  MINK_DRIVER_ARGS_WEBDRIVER="$(echo -e "${MINK_DRIVER_ARGS_WEBDRIVER}" | tr -d '[:space:]')"
  MINK_DRIVER_ARGS_WEBDRIVER=$(sed 's#\\#\\\\#g' <<< $MINK_DRIVER_ARGS_WEBDRIVER)
  echo 'MINK_DRIVER_ARGS_WEBDRIVER='${MINK_DRIVER_ARGS_WEBDRIVER} >> $__env

  # Replace variables.
  sed -i "s#\${REPORT_DIR}#${REPORT_DIR}#g" $__env
  sed -i "s#\${PHP_CODE}#${PHP_CODE}#g" $__env

  if [ -f $__yaml_local ]; then
    yq r $__yaml_local >> $__env
  fi

  # Fix env file format.
  _yml_to_env $__env
}

_env() {
  _generate_env_from_yaml
}

_yml_to_env() {
  __env_file="${1}"
  # Replace : by =.
  sed -i 's#: #=#g' $__env_file
  # Treat 1 / 0 options without double quotes.
  sed -i 's#"1"#1#g' $__env_file
  sed -i 's#"0"#0#g' $__env_file
  # Remove quotes on CI_DRUPAL_VERSION.
  sed -i 's#CI_DRUPAL_VERSION="\(.*\)"#CI_DRUPAL_VERSION=\1#g' $__env_file
  # Add quotes on Nightwatch tests and Chrome opts.
  sed -i 's#NIGHTWATCH_TESTS=\(.*\)#NIGHTWATCH_TESTS="\1"#g' $__env_file

  # Fix selenium local access
  sed -i 's#http://localhost:4444#http://ci-chromedriver:4444#g' $__env_file

  # Replace WEB_ROOT and CI_PROJECT_DIR variables by their values.
  # WEB_ROOT=$(yq r $__yaml_variables "variables.WEB_ROOT")
  # CI_PROJECT_DIR="/builds"
  # REPORT_DIR=$(yq r $__yaml_variables "variables.REPORT_DIR")
  sed -i "s#\${WEB_ROOT}#${WEB_ROOT}#g" $__env_file
  sed -i "s#\${CI_PROJECT_DIR}#${CI_PROJECT_DIR}#g" $__env_file
  sed -i "s#\${REPORT_DIR}#${REPORT_DIR}#g" $__env_file
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
    printf "%s[NOTICE]%s Generate .env file for %s-%s\\n" "${_dim}" "${_end}" "${CI_DRUPAL_VERSION}" "${CI_IMAGE_VARIANT}"
    _generate_env_from_yaml
  else
    printf "%s[NOTICE]%s .env file already here, be sure it's updated\\nrun 'env' function to regenerate.\\n" "${_dim}" "${_end}"
  fi

  if [ -f "$_DIR/docker-compose.yml" ]; then
    docker-compose --project-directory $_DIR -f $_DIR/docker-compose.yml up -d
  else
    printf "%s[ERROR]%s Missing $_DIR/docker-compose.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
  printf "%s[NOTICE]%s Please wait ~10s for DB to be initialized...\\n" "${_dim}" "${_end}"
}

_down() {
  if [ -f "$_DIR/docker-compose.yml" ]; then
    docker-compose --project-directory $_DIR -f $_DIR/docker-compose.yml down
  else
    printf "%s[ERROR]%s Missing $_DIR/docker-compose.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
}

_test() {
  _dkexec_bash "ls -lAh"
}

_copy_output() {
  _dkexec_background cp -r ${WEB_ROOT}/sites/simpletest/browser_output/ ${CI_PROJECT_DIR}/${REPORT_DIR}/${1}
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
  rm -f .env.nightwatch .eslintignore .phpmd.xml .phpqa.yml .sass-lint.yml phpunit.xml.demo phpunit.xml RoboFile.php
}

_check_yq() {
  if ! [ -x "$(command -v yq)" ]; then
    curl -fsSL https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
  fi
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
  elif [ "${_CMD}" == "generate_env_from_yaml" ] || [ "${_CMD}" == "env" ]; then
    _init_variables
    # _generate_env_from_yaml
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
