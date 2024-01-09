#!/bin/bash

# set -ex
set -eE -o functrace

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.

###############################################################################
# Local only tests, not included in Gitlab ci and more flexible.
###############################################################################
__get_robofile() {
  if [ ! -f "$_DIR/../../RoboFile.php" ]; then
    debug "Get remote RoboFile.php to $_DIR/../../RoboFile.php"
    curl -fsSL "${CI_REMOTE_FILES}/RoboFile.php" -o "$_DIR/../../RoboFile.php"
  fi
  if [[ $CI_TYPE == "module" ]]; then
    debug "Copy Robofile to builds"
    _dkexec_bash "cp ${CI_WEB_ROOT}/modules/custom/my-project/RoboFile.php ${CI_PROJECT_DIR}/RoboFile.php"
  fi
}

_build() {

  # before_script
  __get_robofile

  _dkexec_bash "robo ci:build before_build"

  # script
  _dkexec_bash "composer self-update"
  # if [ "${CI_TYPE}" == "module" ]; then
  #   debug "Add require modules to Drupal"
  #   _dkexec_bash "composer --working-dir=/opt/drupal require drush/drush drupal/core-dev phpspec/prophecy-phpunit --dev"
  # fi
  if [ "${CI_TYPE}" == "project" ]; then
    if eval "_exist_file ${CI_PROJECT_DIR}/composer.json"; then
      debug "Add require modules to Drupal"
      _dkexec_bash "composer validate --no-check-all --no-check-publish -n"
      _dkexec_bash "composer install -n --prefer-dist"
      _dkexec_bash "robo drupal:require-dev $CI_SKIP_TEST_BEHAT"
      _dkexec_bash "yarn --cwd ${CI_DRUPAL_WEB_ROOT}/core install"
    fi
  fi

  # after_script
  _dkexec_bash "robo ci:build after_build"
  _dkexec_bash "robo ci:prepare"

  __fix_perm
}

__fix_perm() {
  _dkexec_bash "chown -R www-data:www-data ${CI_WEB_ROOT}"
  _dkexec_bash "chmod -R 755 ${CI_WEB_ROOT}"
}

# Standalone Phpunit test for local tests, can set path as argument.
# Usage:
#   phpunit web/core/modules/action/tests/src/Unit
__phpunit_exec() {
  local __path

  if [[ $CI_TYPE == "module" ]]; then
    __path=${CI_WEB_ROOT}/modules/custom/${CI_PROJECT_NAME}/${_ARGS}
  else
    __path=${_ARGS:-""}
  fi

  debug "Run PHPUnit on $__path"

  if ! eval "_exist_dir ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output"; then
    _dkexec_drupal_bash "mkdir -p ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output"
    _dkexec_drupal_bash "chown -R www-data:www-data ${BROWSERTEST_OUTPUT_DIRECTORY} && chmod -R 777 ${BROWSERTEST_OUTPUT_DIRECTORY}"
  fi

  if ! eval "_exist_file ${CI_WEB_ROOT}/core/phpunit.xml"; then
    # @todo get phpunit.xml somewhere...
    # local _phpunit_conf
    # if [ -f "$_DIR/../../phpunit.xml" ]; then
    #   debug "Use phpunit.xml in the root"
    #   _phpunit_conf="$_DIR/../../phpunit.xml"
    # elif [ -f "$_DIR/../phpunit.xml" ]; then
    #   debug "Use phpunit.xml in .gitlab-ci folder"
    #   _phpunit_conf="$_DIR/../phpunit.xml"
    # elif [ -f "$_DIR/phpunit.xml" ]; then
    #   debug "Use phpunit.xml in .gitlab-ci/local folder"
    #   _phpunit_conf="$_DIR/phpunit.xml"
    # fi

    if [ ! -f "$_DIR/../../phpunit.xml" ]; then
      debug "No phpunit.xml, get a remote version"
      printf "%s[NOTICE]%s Get remote phpunit.xml\\n" "${_dim}" "${_end}"
      curl -fsSL "${CI_REMOTE_FILES}/phpunit.xml" -o "$_DIR/../../phpunit.xml"
    fi
    _dkexec_drupal_bash "cp -f ${CI_PROJECT_DIR}/phpunit.xml ${CI_WEB_ROOT}/core/phpunit.xml"
  fi

  local __extra=""
  if ((_VERBOSE)); then
    __extra="--verbose --debug"
  fi

  _dkexec_drupal_bash "sudo -E -u www-data vendor/bin/phpunit \
    --testsuite ${__phpunit_test_suite} \
    --configuration ${CI_PHPUNIT_CONFIGURATION} \
    ${__extra} \
    ${__path}"
}

_phpunit() {
  printf "\\n%s[INFO]%s PHPUnit: $_ARGS\\n\\n" "${_blu}" "${_end}"
  __phpunit_test_suite=""
  __phpunit_exec
}

_unit() {
  printf "\\n%s[INFO]%s PHPUnit unit\\n\\n" "${_blu}" "${_end}"
  __phpunit_test_suite="unit"
  __phpunit_exec
}

_kernel() {
  printf "\\n%s[INFO]%s PHPUnit kernel\\n\\n" "${_blu}" "${_end}"
  __phpunit_test_suite="kernel"
  __phpunit_exec
}

_func() {
  printf "\\n%s[INFO]%s PHPUnit functional\\n\\n" "${_blu}" "${_end}"
  __phpunit_test_suite="functional"
  __phpunit_exec
}

_funcjs() {
  printf "\\n%s[INFO]%s PHPUnit functional-javascript\\n\\n" "${_blu}" "${_end}"
  __phpunit_test_suite="functional-javascript"
  __phpunit_exec
}

_phpunit_tests() {
  _unit
  _kernel
  _func
  _funcjs
}

# Standalone qa test, can set path as argument and tools with option "-qa".
_phpcs() {
  printf "\\n%s[INFO]%s phpcs\\n\\n" "${_blu}" "${_end}"
  _dkexec phpcs \
    --standard=${CI_QA_PHPCS_STANDARD} \
    --ignore=${CI_QA_IGNORE} \
    --extensions=${CI_QA_SUFFIX} \
    ${CI_DIRS_QA_PHPCS}
}

_phpmd() {
  printf "\\n%s[INFO]%s phpmd\\n\\n" "${_blu}" "${_end}"
  if [ -n "${CI_QA_PHPMD_BASELINE}" ]; then
    _dkexec phpmd ${CI_DIRS_QA_PHPMD} text ${CI_QA_CONFIG_PHPMD} \
      --exclude ${CI_QA_IGNORE} \
      --suffixes ${CI_QA_SUFFIX} \
      --baseline-file ${CI_QA_PHPMD_BASELINE}
  else
    _dkexec phpmd ${CI_DIRS_QA_PHPMD} text ${CI_QA_CONFIG_PHPMD} \
      --exclude ${CI_QA_IGNORE} \
      --suffixes ${CI_QA_SUFFIX}
  fi

}

_phpstan() {
  printf "\\n%s[INFO]%s phpstan\\n\\n" "${_blu}" "${_end}"
  _dkexec phpstan analyze \
    --no-progress \
    --configuration ${CI_QA_CONFIG_PHPSTAN} \
    ${CI_DIRS_QA_PHPSTAN}
}

_qa() {
  _phpcs
  _phpmd
  _phpstan
}

_parallel_lint() {
  printf "\\n%s[INFO]%s parallel-lint\\n\\n" "${_blu}" "${_end}"
  _dkexec parallel-lint \
    --no-progress \
    --exclude vendor \
    -e ${CI_QA_SUFFIX} \
    ${CI_DIRS_LINT_PHP}
}

_js_lint() {
  printf "\\n%s[INFO]%s Eslint\\n\\n" "${_blu}" "${_end}"
  _dkexec node ${CI_WEB_ROOT}/core/node_modules/.bin/eslint \
    --config ${CI_CONFIG_ESLINT} \
    --ignore-path ${CI_CONFIG_ESLINT_IGNORE} \
    --resolve-plugins-relative-to ${CI_WEB_ROOT}/core \
    "${CI_DIRS_LINT_JS}"
}

_yml_lint() {
  printf "\\n%s[INFO]%s Eslint YAML\\n\\n" "${_blu}" "${_end}"
  _dkexec node ${CI_WEB_ROOT}/core/node_modules/.bin/eslint \
    --config ${CI_CONFIG_ESLINT_YAML} \
    --ignore-path ${CI_CONFIG_ESLINT_IGNORE_YAML} \
    --resolve-plugins-relative-to ${CI_WEB_ROOT}/core \
    --ext .yml \
    "${CI_DIRS_LINT_YAML}"
}

_css_lint() {
  printf "\\n%s[INFO]%s Stylelint\\n\\n" "${_blu}" "${_end}"
  _dkexec node ${CI_WEB_ROOT}/core/node_modules/.bin/stylelint \
    --config ${CI_CONFIG_STYLELINT} \
    --ignore-path ${CI_CONFIG_STYLELINT_IGNORE} \
    "${CI_DIRS_LINT_CSS}"
}

_lint() {
  _parallel_lint
  _js_lint
  _yml_lint
  _css_lint
}

# Standalone security test.
_security() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n\\n" "${_blu}" "${_end}"

  _dkexec security-checker --path=/opt/drupal/ -format markdown
}

_behat() {
  _dkexec curl -s -H "Host:localhost" http://chrome:${CI_SERVICE_BEHAT_CHROME_PORT}/json/version | jq '.'

  if [ $_SKIP_INSTALL = 1 ]; then
    printf "%s[SKIP]%s Drupal install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Drupal\\n""${_dim}" "${_end}"
    _dkexec robo drupal:install ${CI_BEHAT_INSTALL_PROFILE} ${CI_BEHAT_INSTALL_DUMP}
  fi

  _dkexec vendor/bin/behat \
    --config ${CI_PROJECT_DIR}/behat_tests/behat.yml \
    --format progress \
    --out std
}

_nightwatch() {
  # NOTE: docker compose stack must expose chromedriver port
  # local _host="chromedriver"
  local _host="localhost"

  if eval "_exist_dir ${CI_PROJECT_DIR}/report-nightwatchjs"; then
    _dkexec_bash "sudo rm -rf ${CI_PROJECT_DIR}/report-nightwatchjs"
  fi
  _dkexec_bash "mkdir -p ${CI_PROJECT_DIR}/report-nightwatchjs/screenshots"
  _dkexec_bash "chown -R www-data:www-data ${CI_PROJECT_DIR}/report-nightwatchjs"
  _dkexec_bash "chmod -R 777 ${CI_PROJECT_DIR}/report-nightwatchjs"

  if ((_VERBOSE)); then
    _status=$(curl -fSsL "http://${_host}:${CI_SERVICE_CHROMEDRIVER_PORT}/status")
    # cat "${_status}" | jq '.'
    echo "${_status}"
  fi

  if ((_SKIP_INSTALL)); then
    debug "Skip Yarn chromedriver upgrade"
  else
    _version=$(curl -s "http://${_host}:${CI_SERVICE_CHROMEDRIVER_PORT}/status" | jq '.value.build.version' | tr -d '"' | cut -d. -f1)
    debug "Upgrade Chromedriver@${_version}"
    docker exec -it -w "${CI_WEB_ROOT}/core" ci-drupal bash -c "yarn -s upgrade chromedriver@${_version}"
  fi

  if ! eval "_exist_file ${CI_WEB_ROOT}/core/.env.tpl"; then
    debug "Copy .env.tpl to drupal core"
    _dkexec_bash "cp ${CI_PROJECT_DIR}/.gitlab-ci/env.tpl ${CI_WEB_ROOT}/core/.env.tpl"
  fi

  _dkexec_bash "envsubst < ${CI_WEB_ROOT}/core/.env.tpl > ${CI_WEB_ROOT}/core/.env"

  if [ "${_ARGS}" ]; then
    CI_NIGHTWATCH_TESTS=${_ARGS}
  fi

  debug "Run test for ${CI_NIGHTWATCH_TESTS}"

  debug "yarn test:nightwatch ${CI_NIGHTWATCH_TESTS}"
  docker exec -it -w "${CI_WEB_ROOT}/core" ci-drupal bash -c "yarn test:nightwatch ${CI_NIGHTWATCH_TESTS}"
}
_nw() {
  _nightwatch
}

###############################################################################
# Variables commands.
###############################################################################

_init_variables() {
  if ((_SKIP_ENV)); then
    source "$_DIR/.env"
  else
    _env
    source $__env
    _clean_env
  fi
}

_clean_env() {
  if [ -f "$_DIR/variables.yml" ]; then
    rm -f "$_DIR/variables.yml"
  fi
}

_env() {

  if [ -f "$_DIR/../../starter.gitlab-ci.yml" ]; then
    debug "Use local starter.gitlab-ci.yml"
    __yaml="$_DIR/../../starter.gitlab-ci.yml"
  elif [ -f "$_DIR/../../.gitlab-ci.yml" ]; then
    debug "Use local .gitlab-ci.yml"
    __yaml="$_DIR/../../.gitlab-ci.yml"
  else
    printf "%s[ERROR]%s Missing .gitlab-ci.yml or starter.gitlab-ci.yml!\\n" "${_red}" "${_end}"
    exit 1
  fi

  if ((_VERBOSE)); then
    printf "%s[Notice]%s Start .env creation\\n" "${_blu}" "${_end}"
  fi

  if [ -f "$_DIR/../ci/variables.yml" ]; then
    debug "Use local variables.yml"
    __yaml_variables="$_DIR/../ci/variables.yml"
  elif [ -f "$_DIR/variables.yml" ]; then
    debug "Use local downloaded variables.yml"
    __yaml_variables="$_DIR/variables.yml"
  else
    debug "Use remote variables.yml"
    curl -fsSL "${CI_REMOTE_FILES}/template/variables.yml" -o "$_DIR/variables.yml"
    __yaml_variables="$_DIR/variables.yml"
  fi

  __yaml_local="$_DIR/local.yml"
  __env="$_DIR/.env"

  _check_yq

  debug "Generate .env file..."

  CI_PROJECT_DIR="/builds"

  if [ -f $__env ]; then
    rm -f $__env
  fi

  touch $__env

  echo "# This file is auto generated, do not edit." >>$__env
  echo "# To update launch:" >>$__env
  echo "# ${_ME} env" >>$__env

  echo 'CI_PROJECT_NAME: my-project' >>$__env
  echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}" >>$__env

  yq r $__yaml_variables "[.default_variables]" --stripComments >>$__env

  echo '# [fix] Override variables from '$__yaml >>$__env
  yq r $__yaml "variables" --stripComments >>$__env

  # Replace variables.
  CI_WEB_ROOT=$(yq r $__yaml_variables "[.default_variables].CI_WEB_ROOT")
  sed -i "s#\${CI_WEB_ROOT}#${CI_WEB_ROOT}#g" $__env
  echo '# [fix] Replaced CI_WEB_ROOT' >>$__env

  CI_DOC_ROOT=$(yq r $__yaml_variables "[.default_variables].CI_DOC_ROOT")
  sed -i "s#\${CI_DOC_ROOT}#${CI_DOC_ROOT}#g" $__env
  echo '# [fix] Replaced CI_DOC_ROOT' >>$__env

  SIMPLETEST_DB=$(yq r $__yaml_variables "[.default_variables].SIMPLETEST_DB")
  sed -i "s#\${SIMPLETEST_DB}#${SIMPLETEST_DB}#g" $__env
  echo '# [fix] Replaced SIMPLETEST_DB' >>$__env

  CI_DB_DRIVER=$(yq r $__yaml_variables "[.default_variables].CI_DB_DRIVER")
  sed -i "s#\${CI_DB_DRIVER}#${CI_DB_DRIVER}#g" $__env
  echo '# [fix] Replaced CI_DB_DRIVER' >>$__env

  CI_REF=$(yq r $__yaml "variables.CI_REF")
  sed -i "s#\${CI_REF}#${CI_REF}#g" $__env
  echo '# [fix] Fixed CI_REF' >>$__env
  echo 'CI_IMAGE_REF="'${CI_REF}'"' >>$__env

  CI_DRUPAL_VERSION=$(yq r $__yaml "variables.CI_DRUPAL_VERSION.value")
  sed -i "s#CI_DRUPAL_VERSION:\(.*\)#CI_DRUPAL_VERSION=${CI_DRUPAL_VERSION}#g" $__env
  echo '# [fix] drupal version' >>$__env

  # Replace some variables by their values from main file.
  CI_DRUPAL_WEB_ROOT=$(yq r $__yaml "variables.CI_DRUPAL_WEB_ROOT")
  sed -i "s#\${CI_DRUPAL_WEB_ROOT}#${CI_DRUPAL_WEB_ROOT}#g" $__env
  echo '# [fix] Replaced CI_DRUPAL_WEB_ROOT' >>$__env

  if [ -f $__yaml_local ]; then
    echo '# [fix] Local override variables local.yml' >>$__env
    yq r $__yaml_local --stripComments >>$__env
  fi

  # Fix MINK_DRIVER_ARGS_WEBDRIVER, remove spaces and escape \.
  sed -i '/MINK_DRIVER_ARGS_WEBDRIVER/d' $__env

  MINK_DRIVER_ARGS_WEBDRIVER=$(yq r $__yaml_variables "[.default_variables].MINK_DRIVER_ARGS_WEBDRIVER")
  # if [ -f $__yaml_local ]; then
  # MINK_DRIVER_ARGS_WEBDRIVER=$(yq r $__yaml_local "MINK_DRIVER_ARGS_WEBDRIVER")
  # fi

  MINK_DRIVER_ARGS_WEBDRIVER="$(echo -e "${MINK_DRIVER_ARGS_WEBDRIVER}" | tr -d '[:space:]')"
  MINK_DRIVER_ARGS_WEBDRIVER=$(sed 's#\\#\\\\#g' <<<$MINK_DRIVER_ARGS_WEBDRIVER)
  echo '# [fix] Fixed MINK_DRIVER_ARGS_WEBDRIVER' >>$__env
  echo 'MINK_DRIVER_ARGS_WEBDRIVER='${MINK_DRIVER_ARGS_WEBDRIVER} >>$__env

  # Fix BEHAT_PARAMS, remove spaces and escape \.
  sed -i '/BEHAT_PARAMS/d' $__env

  BEHAT_PARAMS=$(yq r $__yaml_variables "[.default_variables].BEHAT_PARAMS")
  # if [ -f $__yaml_local ]; then
  #   # BEHAT_PARAMS=$(yq '.BEHAT_PARAMS' $__yaml_local)
  #   BEHAT_PARAMS=$(yq r $__yaml_local "BEHAT_PARAMS")
  # fi

  BEHAT_PARAMS="$(echo -e "${BEHAT_PARAMS}" | tr -d '[:space:]')"
  BEHAT_PARAMS=$(sed 's#\\#\\\\#g' <<<$BEHAT_PARAMS)
  echo '# [fix] Fixed BEHAT_PARAMS' >>$__env
  echo 'BEHAT_PARAMS='${BEHAT_PARAMS} >>$__env

  # Fix env file format.
  _yml_to_env_fixes $__env

  printf "%s[Done]%s .env created\\n" "${_gre}" "${_end}"
}

_yml_to_env_fixes() {
  # Remove obsolete values.
  sed -i '/^extends:/d' $__env
  # Delete empty lines.
  sed -i '/^$/d' $__env
  # Delete lines starting with spaces.
  sed -i '/^ /d' $__env
  # Replace : by =.
  sed -i 's#: #=#g' $__env
  # Treat 1 / 0 options without double quotes.
  sed -i 's#"1"#1#g' $__env
  sed -i 's#"0"#0#g' $__env
}
