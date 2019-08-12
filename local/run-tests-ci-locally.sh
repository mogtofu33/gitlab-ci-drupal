#!/bin/bash

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.yml

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
_DEBUG=0

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
      _DEBUG=1
      shift
      ;;
    --full-debug)
      printf ">>> [NOTICE] FULL Debug mode on!\\n"
      set -o xtrace
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
    eslint
    stylelint
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
  --full-debug                    Debug this script.

HEREDOC
}

###############################################################################
# Program Functions
###############################################################################

_status() {

  _status_vars

  _dkexecb /scripts/run-tests.sh
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
  ${CI_TYPE} ${DOC_ROOT} ${WEB_ROOT} ${CI_PROJECT_DIR} ${REPORT_DIR}
  printf "APACHE_RUN_USER: %s\\nAPACHE_RUN_GROUP: %s\\nPHPUNIT_TESTS: %s\\nBROWSERTEST_OUTPUT_DIRECTORY: %s\\nMINK_DRIVER_ARGS_WEBDRIVER: %s\\n" \
  ${APACHE_RUN_USER} ${APACHE_RUN_GROUP} ${PHPUNIT_TESTS} ${BROWSERTEST_OUTPUT_DIRECTORY} ${MINK_DRIVER_ARGS_WEBDRIVER}
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

  if ! [ -f tmp/artifacts.tgz ]
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
  if [ -f tmp/artifacts.tgz ]
  then
    printf ">>> [NOTICE] extract_artifacts..."
    mv tmp/artifacts.tgz .
    _dkexec tar -xzf ${CI_PROJECT_DIR}/artifacts.tgz
    mkdir -p tmp
    mv artifacts.tgz tmp/
    printf " Done!\\n"
  else
    printf ">>> [SKIP] No artifacts!\\n" "${_blu}" "${_end}"
  fi
}

# Replicate Build job cache.
_simulate_cache() {
  printf ">>> [NOTICE] simulate_cache\\n"
  _extract_artifacts
  if ! [ ${CI_TYPE} == "project" ]; then
    if [ -f 'composer.lock' ] || [ -f 'load.environment.php' ]; then
      sudo rm -rf drush scripts composer.json composer.lock .env.example load.environment.php
    fi
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
  _dkexec cp -r ${WEB_ROOT}/${REPORT_DIR} ./
  # bash <(curl -s https://codecov.io/bash) -f ${REPORT_DIR}/coverage.xml -t ${CODECOV_TOKEN}
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
  if [ $__clean == 1 ];
  then
    _clean_browser_output
    sudo rm -rf reports/functional
  fi
  _dkexec sudo -E -u ${APACHE_RUN_USER} robo $__simulate test:suite ${PHPUNIT_TESTS}functional
  _copy_output functional
}

_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n\\n" "${_blu}" "${_end}"
  # Starting Selenium.
  docker exec -d ci-drupal /scripts/start-selenium-standalone.sh
  sleep 5s

  _build
  _tests_prepare

  if [ ${_DEBUG} == "1" ]; then
    _dkexecb "curl -s http://localhost:4444/wd/hub/status | jq '.'"
  fi

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${REPORT_DIR}

  _functional_js_cmd
}

_functional_js_cmd() {
  if [ $__clean == 1 ];
  then
    _clean_browser_output
    sudo rm -rf reports/functional-javascript
  fi
  _dkexec sudo -E -u ${APACHE_RUN_USER} robo $__simulate test:suite ${PHPUNIT_TESTS}functional-javascript
  # _dkexec sudo -E -u ${APACHE_RUN_USER} robo $__simulate test:phpunit ${PHPUNIT_TESTS}functional-javascript

  _copy_output functional-javascript

}

_nightwatch() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _dkexec cp -u ${CI_PROJECT_DIR}/.gitlab-ci/.env.nightwatch ${WEB_ROOT}/core/.env

  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] patch_nightwatch\\n"
  else
    _patch_nightwatch
  fi

  _copy_robofile
  _prepare_folders

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites

  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] yarn install / chrome check\\n"
  else
    docker exec -it -w ${WEB_ROOT}/core ci-drupal yarn install
    _ensure_chrome
  fi

  _dkexec mkdir -p ${REPORT_DIR}/nightwatch
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${REPORT_DIR}/nightwatch
  _dkexec mkdir -p ${WEB_ROOT}/core/reports/
  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/core/reports/

  _nightwatch_cmd

  _dkexec mkdir -p ${CI_PROJECT_DIR}/${REPORT_DIR}/nightwatch
  _dkexec cp -r ${WEB_ROOT}/core/reports/report.html ${CI_PROJECT_DIR}/${REPORT_DIR}/nightwatch/
}

_patch_nightwatch() {
  printf ">>> [NOTICE] Patching nightwatch to upgrade to ^1.1"
  _dkexecb "curl -fsSL https://www.drupal.org/files/issues/2019-08-12/3059356-21.patch -o ${WEB_ROOT}/upgrade.patch"
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

  if [ $__clean == 1 ];
  then
    # _clean_browser_output
    sudo rm -rf reports/nightwatch
  fi

  __verbose=""
  if [ ${VERBOSE} == "1" ]; then
    __verbose="--verbose"
  fi

  if [ $__skip_prepare = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] patch_nightwatch\\n"
  else
    _test_html_reporter=$(docker exec -t ci-drupal sh -c "[ -f ${WEB_ROOT}/core/node_modules/.bin/nightwatch-html-reporter ] && echo true")
    if [ -z "${_test_html_reporter}" ]; then
      docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "yarn add nightwatch-html-reporter"
    fi
  fi

  _dkexec cp -u ${CI_PROJECT_DIR}/.gitlab-ci/html-reporter.js ${WEB_ROOT}/core/html-reporter.js

  # docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "yarn test:nightwatch ${__verbose} ${NIGHTWATCH_TESTS} --reporter ./html-reporter.js"
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

  DRUPAL_INSTALL_PROFILE=$(yq r ./.gitlab-ci.yml "[Behat tests].variables.DRUPAL_INSTALL_PROFILE")
  _install_drupal

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites

  # Starting Chrome.
  _ensure_chrome
  docker exec -d ci-drupal bash -c "/scripts/start-chrome.sh"
  sleep 5s

  if [ ${_DEBUG} == "1" ]; then
    _dkexecb "curl -s http://localhost:9222/json/version | jq '.'"
  fi

  _behat_cmd
}

_install_drupal() {
  if [ $__skip_install = 1 ] || [ $__skip_all = 1 ]; then
    printf ">>> [SKIP] install\\n"
  else
    printf ">>> [NOTICE] install Drupal\\n"
    if [ -z ${DRUPAL_INSTALL_PROFILE} ]; then
      $__drupal_profile = ${DRUPAL_INSTALL_PROFILE}
    fi
    _dkexec robo $__simulate install:drupal $__drupal_profile
  fi
}

_behat_cmd() {

  if [ $__clean == 1 ];
  then
    # _clean_browser_output
    sudo rm -rf reports/behat
  fi
  _dkexec drush cr
  _dkexec robo $__simulate test:behat "${CI_PROJECT_DIR}/${REPORT_DIR}"
}


_pa11y() {
  printf "\\n%s[INFO]%s Perform job 'Pa11y' (pa11y)\\n\\n" "${_blu}" "${_end}"

  _build
  _tests_prepare

  _copy_robofile
  _prepare_folders

  DRUPAL_INSTALL_PROFILE=$(yq r ./.gitlab-ci.yml "[Pa11y].variables.DRUPAL_INSTALL_PROFILE")
  _install_drupal

  _dkexec chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} ${WEB_ROOT}/sites

  _dkexec cp ${CI_PROJECT_DIR}/.gitlab-ci/pa11y-ci.json ${WEB_ROOT}/core
  docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "yarn add pa11y-ci"

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/pa11y*.png
  fi

  docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "node_modules/.bin/pa11y-ci --config ./pa11y-ci.json"

  _dkexecd cp -f ${WEB_ROOT}/core/reports/pa11y*.png ${CI_PROJECT_DIR}/${REPORT_DIR}/
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

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/code_quality
  fi

  _dkexecb "phpqa \${PHPQA_REPORT}/code_quality --tools \${TOOLS} ${PHPQA_PHP_CODE}"
}

_best_practices() {
  printf "\\n%s[INFO]%s Perform job 'Best practices' (best_practices)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  sed -i 's/Drupal/DrupalPractice/g' .phpqa.yml
  _prepare_folders

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/best_practices
  fi

  _dkexecb "phpqa \${PHPQA_REPORT}/best_practices --tools \${BEST_PRACTICES} ${PHPQA_PHP_CODE}"
}

####### Lint jobs

_eslint() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/js-lint-report.html
  fi

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

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/sass-lint-report.html
  fi

  # _dkexecb "${WEB_ROOT}/core/node_modules/.bin/sass-lint --config \${SASS_CONFIG} --verbose --no-exit"
  _dkexecb "${WEB_ROOT}/core/node_modules/.bin/sass-lint --config \${SASS_CONFIG} --verbose --no-exit --format html --output ${REPORT_DIR}/sass-lint-report.html"
}

####### Metrics jobs

_phpmetrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (phpmetrics)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/phpmetrics
  fi

  _dkexecb "phpqa \${PHPQA_REPORT}/phpmetrics --tools phpmetrics ${PHPQA_PHP_CODE}"
}

_phpstats() {
  printf "\\n%s[INFO]%s Perform job 'Php stats' (phpstats)\\n\\n" "${_blu}" "${_end}"
  _cp_qa_lint_metrics
  _prepare_folders

  if [ $__clean == 1 ];
  then
    sudo rm -rf reports/phpstats
  fi

  _dkexecb "phpqa \${PHPQA_REPORT}/phpstats --tools phploc,pdepend ${PHPQA_PHP_CODE}"
}

###############################################################################
# Docker helpers commands.
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_DEBUG)); then printf " :::: [DEBUG] %s called by %s\\n" "$FUNCNAME" "${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal "$@" || true
  fi
}

_dkexecd() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_DEBUG)); then printf " :::: [DEBUG] %s called by %s\\n" "$FUNCNAME" "${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -d -w ${CI_PROJECT_DIR} ci-drupal "$@" || true
  fi
}

_dkexecb() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_DEBUG)); then printf " :::: [DEBUG] %s called by %s\\n" "$FUNCNAME" "${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
  fi
}

###############################################################################
# Helpers commands.
###############################################################################

_init_variables() {
  __yaml="./.gitlab-ci.yml"
  __yaml_variables="./.gitlab-ci/.gitlab-ci-variables.yml"

  CI_PROJECT_DIR="/builds"
  VERBOSE=$(yq r $__yaml_variables variables.VERBOSE)
  CI_TYPE=$(yq r $__yaml_variables variables.CI_TYPE)
  WEB_ROOT=$(yq r $__yaml_variables variables.WEB_ROOT)
  DOC_ROOT=$(yq r $__yaml_variables variables.DOC_ROOT)
  REPORT_DIR=$(yq r $__yaml_variables variables.REPORT_DIR)
  PHPUNIT_TESTS=$(yq r $__yaml_variables variables.PHPUNIT_TESTS)
  PHP_CODE=$(yq r $__yaml_variables variables.PHP_CODE)
  PHPQA_IGNORE_DIRS=$(yq r $__yaml_variables variables.PHPQA_IGNORE_DIRS)
  PHPQA_IGNORE_FILES=$(yq r $__yaml_variables variables.PHPQA_IGNORE_FILES)
  NIGHTWATCH_TESTS=$(yq r $__yaml_variables variables.NIGHTWATCH_TESTS)
  PHPQA_PHP_CODE=$(yq r $__yaml_variables variables.PHPQA_PHP_CODE)

  DRUPAL_SETUP_FROM_CONFIG=$(yq r $__yaml [.test_variables].DRUPAL_SETUP_FROM_CONFIG)
  APACHE_RUN_USER=$(yq r $__yaml [.test_variables].APACHE_RUN_USER)
  APACHE_RUN_GROUP=$(yq r $__yaml [.test_variables].APACHE_RUN_GROUP)
  BROWSERTEST_OUTPUT_DIRECTORY=$(yq r $__yaml [.test_variables].BROWSERTEST_OUTPUT_DIRECTORY)
  BROWSERTEST_OUTPUT_DIRECTORY=$(echo $BROWSERTEST_OUTPUT_DIRECTORY | sed "s#\${WEB_ROOT}#${WEB_ROOT}#g")
  DRUPAL_INSTALL_PROFILE="standard"

  # Overriden variables (simulate Gitlab-CI UI)
  if [ -f "local/.local.env" ]; then
    source local/.local.env
  else
    touch local/.local.env
  fi
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

  if ! [ -f "./.gitlab-ci/.gitlab-ci-variables.yml" ]; then
    printf "%s[ERROR]%s Missing .gitlab-ci-variables.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi

  __yaml="./.gitlab-ci.yml"
  __yaml_variables="./.gitlab-ci/.gitlab-ci-variables.yml"
  __env="./local/.env"

  if [ -f $__env ]; then
    rm -f $__env
  fi

  touch $__env
  echo 'CI_PROJECT_NAME: my_module' >> $__env
  echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}" >> $__env

  yq r $__yaml_variables variables >> $__env
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
  # Treat 1 / 0 options without double quotes.
  sed -i 's#"1"#1#g' $__env
  sed -i 's#"0"#0#g' $__env
  # Remove quotes on DRUPAL_VERSION.
  sed -i 's#DRUPAL_VERSION="8\(.*\)"#DRUPAL_VERSION=8\1#g' $__env
  # sed -i 's/MINK_DRIVER_ARGS_WEBDRIVER/#MINK_DRIVER_ARGS_WEBDRIVER/g' $__env
  # Remove single quotes
  sed -i "s#'##g" $__env
  # Fix selenium local.
  sed -i 's#http://localhost:4444#http://127.0.0.1:4444#g' $__env

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
  _test_chrome=$(docker exec -t ci-drupal sh -c "[ -f /usr/bin/chromium ] && echo true")
  if [ -z "${_test_chrome}" ]; then
    docker exec -t ci-drupal sudo apt update && sudo apt install -y chromium
  fi
  docker exec -t ci-drupal chromium --version
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
  if ! [ -f "./local/.env" ]; then
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
  _dkexecd cp -r ${DOC_ROOT}/sites/simpletest/browser_output/ ${CI_PROJECT_DIR}/${REPORT_DIR}/${1}
}
_copy_output_functional() {
  _copy_output functional
}
_copy_output_functional_js() {
  _copy_output functional-javascript
}

_clean() {
  _clean_config
  sudo rm -rf reports
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
    $__call
  else
    printf "%s[ERROR]%s Unknown command: %s\\nRun --help for usage.\\n" "${_red}" "${_end}" "${_CMD}"
  fi
}

# Call `_main` after everything has been defined.
_main
