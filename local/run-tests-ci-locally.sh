#!/bin/bash

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.yml

set -o nounset
set -o errexit
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR
set -o errtrace
set -o pipefail
IFS=$'\n\t'

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

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0

__skip_prepare=0
__skip_build=0
__skip_install=0
__skip_all=0
__simulate=""

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
      __skip_prepare=1
      shift
      ;;
    -sb|--skip-build)
      __skip_build=1
      shift
      ;;
    -si|--skip-install)
      __skip_install=1
      shift
      ;;
    -sa|--skip-all)
      __skip_all=1
      shift
      ;;
    -sim|--simulate)
      printf ">>> [NOTICE] simulate robo\\n"
      __simulate="--simulate"
      __skip_all=1
      shift
      ;;
    --endopts)
      Terminate option parsing.
      break
      ;;
    *)
      _CMD+=("$1")
      shift
      ;;
  esac
done

_ARGS=${_CMD[@]:1}

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
    unit              Run unit tests + nightwatch + behat.
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
    code_quality
    best_practices
    eslint
    stylelint
    sass_lint
    phpmetrics
    phpstat

Options
  -h|--help                       Print help.
  -sp|--skip-prepare              Skip prepare step (copy files, set folders).
  -sb|--skip-build                Skip build step (cache, perform build).
  -si|--skip-install              Skip Drupal install step (behat).
  -sa|-spb|--skip-prepare-build   Skip bith previous.
  -sim|--simulate                 Robo simulate action.

HEREDOC
}

###############################################################################
# Program Functions
###############################################################################

_status() {

  _status_vars

  _dkexecb /scripts/run-tests.
  sleep 2s
  docker exec -d ci-drupal bash -c "/scripts/start-selenium-standalone.
  sleep 2s"
  # sleep 2s
  printf "Selenium running? (If nothing, no!)\\n"
  _dkexecb "curl -s http://localhost:4444/wd/hub/status | jq '.'"
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.
  sleep 2s"
  # sleep 1s
  printf "Chrome running? (If nothing, no!)\\n"
  _dkexecb "curl -s http://localhost:9222/json/version | jq '.'"

  printf "\\n"
}

_status_vars() {

  printf "CI_TYPE: %s\\nDOC_ROOT: %s\\nWEB_ROOT: %s\\nCI_PROJECT_DIR: %s\\nREPORT_DIR: %s\\n" \
  ${CI_TYPE} ${WEB_ROOT} ${DOC_ROOT} ${CI_PROJECT_DIR} ${REPORT_DIR}
  printf "APACHE_RUN_USER: %s\\nAPACHE_RUN_GROUP: %s\\nPHPUNIT_TESTS: %s\\nBROWSERTEST_OUTPUT_DIRECTORY: %s\\n" \
  ${APACHE_RUN_USER} ${APACHE_RUN_GROUP} ${PHPUNIT_TESTS} ${BROWSERTEST_OUTPUT_DIRECTORY}
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

    _copy_robofile

    _prepare_folders
    
    # Apache launch is entrypoint.
    # docker exec -d ci-drupal bash -c "apache2-foreground"

    # Prepare needed folders, reproduce .test_template
    _dkexec cp -u ${CI_PROJECT_DIR}/local/phpunit.local.xml ${WEB_ROOT}/core/phpunit.xml

    # RoboFile.php is already at root.
    _dkexec mkdir -p ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output
    _dkexec chmod -R g+s ${BROWSERTEST_OUTPUT_DIRECTORY}
    _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${BROWSERTEST_OUTPUT_DIRECTORY}
  fi
}

# Replicate Build job.
_build() {
  if [ $__skip_build = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] build\\n"
    _copy_robofile
  else
    printf ">>> [NOTICE] build\\n"
    _simulate_cache

    _copy_robofile

    _dkexec robo $__simulate perform:build

    _create_artifacts
  fi
}

_prepare_folders() {
  if [ $__skip_prepare = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] prepare_folders\\n"
  else
    _copy_robofile
    _dkexec robo $__simulate prepare:folders
  fi
}

_create_artifacts() {

  printf ">>> [NOTICE] Uploading artifacts...\\n"

  if ! [ -f tmp/artifacts.tgz ] && [ -f web/index.php ]
  then
    mkdir -p tmp
    tar -czf tmp/artifacts.tgz \
      --exclude="web/modules/custom" --exclude="web/themes/custom" \
      vendor web drush scripts composer.json composer.lock .env.example load.environment.php
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
  if ! [ ${CI_TYPE} == "project" ]; then
    sudo rm -rf drush scripts composer.json composer.lock .env.example load.environment.php
  fi
}

_copy_robofile() {
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/RoboFile.php ${CI_PROJECT_DIR}
}
####### Tests jobs

_unit_kernel() {
  printf "\\n%s[INFO]%s Perform job 'Unit and kernel tests' (unit_kernel)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare
  _dkexec robo $__simulate test:suite "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_code_coverage() {
  printf "\\n%s[INFO]%s Perform job 'Code coverage' (code_coverage)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare
  _dkexec robo $__simulate test:coverage "${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel"
}

_functional() {
  printf "\\n%s[INFO]%s Perform job 'Functional' (functional)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${REPORT_DIR}
  _functional_cmd
}

_functional_cmd() {
  _dkexec sudo -E -u ${APACHE_RUN_USER} robo $__simulate test:suite ${PHPUNIT_TESTS}functional
  _dkexecd cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional
}

_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n\\n" "${_blu}" "${_end}"
  # Starting Selenium.
  docker exec -d ci-drupal /scripts/start-selenium-standalone.sh
  sleep 5s

  _build
  _tests_prepare

  _dkexecb "curl -s http://localhost:4444/wd/hub/status | jq '.'"

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${REPORT_DIR}

  _functional_js_cmd
}

_functional_js_cmd() {
  _dkexec sudo -E -u ${APACHE_RUN_USER} robo $__simulate test:suite ${PHPUNIT_TESTS}functional-javascript
  # _dkexec robo $__simulate test:suite "${PHPUNIT_TESTS}functional-javascript"

  _dkexecd cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/functional-javascript
}

_nightwatch() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec cp -u ${CI_PROJECT_DIR}/.gitlab-ci/.env.nightwatch ${WEB_ROOT}/core/.env

  _patch_nightwatch

  _dkexec cp -u ${CI_PROJECT_DIR}/.gitlab-ci/nightwatch.conf.js ${WEB_ROOT}/core/nightwatch.conf.js

  _copy_robofile
  _prepare_folders

  printf ">>> [NOTICE] Chown docroot, can be long..."
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${DOC_ROOT}
  printf "Done!\\n"

  docker exec -it -w ${WEB_ROOT}/core ci-drupal yarn install
  _ensure_chrome
  _nightwatch_cmd
}

_patch_nightwatch() {
  printf ">>> [NOTICE] Patching nightwatch to upgrade to ^1.10"
  _dkexecb "curl -fsSL https://www.drupal.org/files/issues/2019-07-02/3059356-12-nightwatch-upgrade.patch -o ${WEB_ROOT}/upgrade.patch"
  docker exec -d -w ${WEB_ROOT} ci-drupal bash -c "patch -N -p1 < ${WEB_ROOT}/upgrade.patch"
  sleep 2s
  docker exec -it -w ${WEB_ROOT}/core ci-drupal yarn install
  printf "\\n"
  docker exec -it ci-drupal ${WEB_ROOT}/core/node_modules/.bin/nightwatch --version
  printf " Done!\\n"

  printf ">>> [NOTICE] Patching nightwatch for Drupal profile support..."
  _dkexecb "curl -fsSL https://www.drupal.org/files/issues/2019-02-05/3017176-7.patch -o ${WEB_ROOT}/3017176-7.patch"
  docker exec -d -w ${WEB_ROOT} ci-drupal bash -c "patch -N -p1 < ${WEB_ROOT}/3017176-7.patch"
  sleep 2s
  printf "Done!\\n"
}

_nightwatch_cmd() {
  __verbose=""
  if [ ${VERBOSE} == "1" ]; then
    __verbose="--verbose"
  fi
  docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "yarn test:nightwatch ${__verbose} ${NIGHTWATCH_TESTS}"
}

_test_site() {
  if [ ${_ARGS} == "install" ]; then
    docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "sudo -u www-data php ./scripts/test-site.php install --setup-file 'core/tests/Drupal/TestSite/TestSiteInstallTestScript.php' --install-profile 'demo_umami' --base-url http://localhost --db-url mysql://root@mariadb/drupal"
  else
    docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "sudo -u www-data php ./scripts/test-site.php ${_ARGS}"
  fi
}

_behat() {
  printf "\\n%s[INFO]%s Perform job 'Behat' (behat)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _copy_robofile
  _prepare_folders

  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] install\\n"
  else
    printf ">>> [NOTICE] install\\n"
    _dkexec robo $__simulate install:drupal standard
  fi

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites

  # Starting Chrome.
  _ensure_chrome
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.sh"
  sleep 5s
  _dkexecb "curl -s http://localhost:9222/json/version | jq '.'"

  _behat_cmd
}

_behat_cmd() {
  _dkexec robo $__simulate test:behat "${CI_PROJECT_DIR}/${REPORT_DIR}"
}

_security_checker() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n\\n" "${_blu}" "${_end}"

  _build
  _copy_robofile
  _prepare_folders

  _dkexec security-checker security:check
}

####### QA jobs

# Replicate cp in all qa / lint / metrics jobs
_cp_qa_lint_metrics() {
  # Place config files in a proper directory.
  printf ">>> [NOTICE] cp config\\n"
  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/.phpmd.xml ${CI_PROJECT_DIR}/.gitlab-ci/.phpqa.yml ${CI_PROJECT_DIR}/.gitlab-ci/.eslintignore ${CI_PROJECT_DIR}
}

_code_quality() {
  printf "\\n%s[INFO]%s Perform job 'Code quality' (code_quality)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexecb "phpqa \${PHPQA_REPORT}/code_quality \${TOOLS} \${PHPQA_PHP_CODE}"
}

_best_practices() {
  printf "\\n%s[INFO]%s Perform job 'Best practices' (best_practices)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml
  _prepare_folders

  _dkexecb "phpqa \${PHPQA_REPORT}/best_practices --tools \${BEST_PRACTICES} \${PHPQA_PHP_CODE}"
}

####### Lint jobs

_eslint() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  # _dkexecb "eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json \${JS_CODE}"
  _dkexecb "eslint --config ${WEB_ROOT}/core/.eslintrc.passing.json --format html --output-file ${REPORT_DIR}/js-lint-report.html \${JS_CODE}"
}

_stylelint() {
  printf "\\n%s[INFO]%s Perform job 'Css lint' (stylelint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexecb "stylelint --config-basedir /var/www/.node/node_modules/ \
    --config ${WEB_ROOT}/core/.stylelintrc.json -f verbose \${CSS_FILES}"
}

_sass_lint() {
  printf "\\n%s[INFO]%s Perform job 'Sass lint' (sass_lint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  printf ">>> [NOTICE] Install Sass-lint\\n"
  docker exec -it -w ${WEB_ROOT}/core ci-drupal npm install --no-audit git://github.com/sasstools/sass-lint.git#develop

  _dkexecb "${WEB_ROOT}/core/node_modules/.bin/sass-lint --config \${SASS_CONFIG} --verbose --no-exit"
  _dkexecb "${WEB_ROOT}/core/node_modules/.bin/sass-lint --config \${SASS_CONFIG} --verbose --no-exit --format html --output ${REPORT_DIR}/sass-lint-report.html"
}

####### Metrics jobs

_phpmetrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (phpmetrics)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexecb "phpqa \${PHPQA_REPORT}/phpmetrics --tools phpmetrics \${PHPQA_PHP_CODE}"
}

_phpstat() {
  printf "\\n%s[INFO]%s Perform job 'Php stats' (phpstat)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  _dkexecb "phpqa \${PHPQA_REPORT}/phpstat --tools phploc,pdepend \${PHPQA_PHP_CODE}"
}

###############################################################################
# Docker helpers commands.
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal "$@"
  fi
}

_dkexecd() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -d -w ${CI_PROJECT_DIR} ci-drupal "$@"
  fi
}

_dkexecb() {
  if ! [ -f "/.dockerenv" ]; then
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
  fi
}

###############################################################################
# Helpers commands.
###############################################################################

_init_variables() {
  CI_PROJECT_DIR="/builds"
  VERBOSE=$(yq r ./.gitlab-ci.yml variables.VERBOSE)
  CI_TYPE=$(yq r ./.gitlab-ci.yml variables.CI_TYPE)
  WEB_ROOT=$(yq r ./.gitlab-ci.yml variables.WEB_ROOT)
  DOC_ROOT=$(yq r ./.gitlab-ci.yml variables.DOC_ROOT)
  REPORT_DIR=$(yq r ./.gitlab-ci.yml variables.REPORT_DIR)
  PHPUNIT_TESTS=$(yq r ./.gitlab-ci.yml variables.PHPUNIT_TESTS)
  PHP_CODE=$(yq r ./.gitlab-ci.yml variables.PHP_CODE)
  PHPQA_IGNORE_DIRS=$(yq r ./.gitlab-ci.yml variables.PHPQA_IGNORE_DIRS)
  PHPQA_IGNORE_FILES=$(yq r ./.gitlab-ci.yml variables.PHPQA_IGNORE_FILES)
  NIGHTWATCH_TESTS=$(yq r ./.gitlab-ci.yml variables.NIGHTWATCH_TESTS)

  APACHE_RUN_USER=$(yq r ./.gitlab-ci.yml [.test_variables].APACHE_RUN_USER)
  APACHE_RUN_GROUP=$(yq r ./.gitlab-ci.yml [.test_variables].APACHE_RUN_GROUP)
  BROWSERTEST_OUTPUT_DIRECTORY=$(yq r ./.gitlab-ci.yml [.test_variables].BROWSERTEST_OUTPUT_DIRECTORY)
  BROWSERTEST_OUTPUT_DIRECTORY=$(echo $BROWSERTEST_OUTPUT_DIRECTORY | sed "s#\${WEB_ROOT}#${WEB_ROOT}#g")

}

_init() {
  _init_variables
}

_generate_env_from_yaml() {
  printf "[NOTICE] Generate .env file..."
  _init_variables

  if ! [ -x "$(command -v yq)" ]; then
    curl -fsSL https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
  fi

  if ! [ -f "./.gitlab-ci.yml" ]; then
    printf "%s[ERROR]%s Missing .gitlab-ci.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
  __yaml="./.gitlab-ci.yml"
  __env="./local/.gitlab-ci.env"

  if [ -f $__env ]; then
    rm -f $__env
  fi

  touch $__env
  echo 'CI_PROJECT_NAME: my_module' >> $__env
  echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}" >> $__env

  yq r $__yaml variables >> $__env
  yq r $__yaml "[.test_variables]" >> $__env

  CHROMIUM_OPTS=$(yq r $__yaml "[Behat tests].variables.CHROMIUM_OPTS")
  echo 'CHROMIUM_OPTS='"${CHROMIUM_OPTS}"'' >> $__env
  # Fix BEHAT_PARAMS, remove spaces and escape \.
  BEHAT_PARAMS=$(yq r $__yaml "[Behat tests].variables.BEHAT_PARAMS")
  BEHAT_PARAMS="$(echo -e "${BEHAT_PARAMS}" | tr -d '[:space:]')"
  BEHAT_PARAMS=$(sed 's#\\#\\\\#g' <<< $BEHAT_PARAMS)
  echo 'BEHAT_PARAMS='${BEHAT_PARAMS} >> $__env

  sed -i "s#\${CI_PROJECT_DIR}#${CI_PROJECT_DIR}#g" $__env
  sed -i "s#\${REPORT_DIR}#${REPORT_DIR}#g" $__env
  sed -i "s#\${PHP_CODE}#${PHP_CODE}#g" $__env
  sed -i "s#\${PHPQA_IGNORE_DIRS}#${PHPQA_IGNORE_DIRS}#g" $__env
  sed -i "s#\${PHPQA_IGNORE_FILES}#${PHPQA_IGNORE_FILES}#g" $__env

  sed -i 's#: #=#g' $__env
  # Remove empty values.
  sed -i 's#""##g' $__env
  # Treat 1 / 0 options without dble quotes.
  sed -i 's#"1"#1#g' $__env
  sed -i 's#"0"#0#g' $__env

  # __WEB_ROOT=$(yq r $__yaml variables.WEB_ROOT)
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
  if ! [ -x "$(command -v chromium)" ]; then
    sudo apt update && sudo apt install -y chromium
  fi
}

_reset() {
  printf "\\n%s[INFO]%s Reset stack to mimic Gitlab-ci\\n" "${_blu}" "${_end}"
  _down
  _clean_config
  _clean_custom
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
  if ! [ -f "./local/.gitlab-ci.env" ]; then
    _generate_env_from_yaml
  fi

  if [ -f "local/docker-compose.yml" ]; then
    docker-compose -f local/docker-compose.yml up -d
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
  if [ -f "local/docker-compose.yml" ]; then
    docker-compose -f local/docker-compose.yml down
  else
    if [ -f "docker-compose.yml" ]; then
      docker-compose down
    else
      printf "%s[ERROR]%s Missing docker-compose.yml file.\\n" "${_red}" "${_end}"
      exit 1
    fi
  fi
}

_copy_output() {
  _dkexecd cp -f ${DOC_ROOT}/sites/simpletest/browser_output/*.html ${REPORT_DIR}/
}

_clean() {
  _clean_config
  sudo rm -rf reports
  # _dkexecd "rm -rf ${DOC_ROOT}/sites/simpletest/browser_output/*.html"
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
  sudo rm -rf drush scripts vendor \
    web/core web/sites web/profiles web/.* web/*.php web/robots.txt web/web.config \
    .editorconfig .env.example .gitattributes .travis.yml composer.* load.environment.php phpunit.xml.dist | true
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
  _phpstat
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
    $__call
  else
    printf "%s[ERROR]%s Unknown command: %s\\n" "${_red}" "${_end}" "${_CMD}"
    _help
  fi
}

# Call `_main` after everything has been defined.
_main
