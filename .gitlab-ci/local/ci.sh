#!/bin/bash
# set -ex

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.

###############################################################################
# Local only tests, not included in Gitlab ci and more flexible.
###############################################################################
__get_robofile() {
  if [ ! -f "RoboFile.php" ]; then
    _dkexec_bash "curl -fsSL ${CI_REMOTE_FILES}/RoboFile.php -o RoboFile.php;"
  fi
}

__build() {
  # before_script
  __get_robofile
  _dkexec_bash "robo ci:build before_build"

  # script
  _dkexec_bash "composer self-update;"
  if [ "${CI_TYPE}" == "project" ]; then
    if eval "_exist_file ${CI_PROJECT_DIR}/composer.json"; then
      _dkexec_bash "composer validate --no-check-all --no-check-publish -n;"
      _dkexec_bash "composer install -n --prefer-dist;"
      _dkexec_bash "composer require -n --dev \
        'drupal/core-dev:~${CI_DRUPAL_VERSION}' \
        drush/drush \
        'phpspec/prophecy-phpunit:^2'"
      _dkexec_bash "composer require -n --dev \
        'drupal/drupal-extension:~4.1' \
        'dmore/behat-chrome-extension:^1.3' \
        'emuse/behat-html-formatter:0.2.*' \
        'friends-of-behat/mink-extension:^2.6';"
    fi
  fi

  # after_script
  _dkexec_bash "robo ci:build"
  # _dkexec_bash "robo ci:prepare"
}

__install_phpunit() {
  if ! eval "_exist_file /opt/drupal/vendor/bin/phpunit"; then
    if [ "${CI_TYPE}" == "project" ]; then
      if eval "_exist_file /opt/drupal/composer.json"; then
        _dkexec_bash "composer require --no-ansi -n -d /opt/drupal --dev 'drupal/core-dev:~${CI_DRUPAL_VERSION}';"
      fi
    fi
  fi

  if ! eval "_exist_dir /opt/drupal/vendor/phpspec/prophecy-phpunit"; then
    if [ "${CI_TYPE}" == "project" ]; then
      if eval "_exist_file /opt/drupal/composer.json"; then
        _dkexec_bash "composer require --no-ansi -n -d /opt/drupal --dev 'phpspec/prophecy-phpunit:^2';"
      fi
    fi
  fi

  _dkexec ${CI_DOC_ROOT}/vendor/bin/phpunit --version
}

# Standalone Phpunit test for local tests, can set path as argument.
# Usage:
#   phpunit web/core/modules/action/tests/src/Unit
_phpunit() {
  # __install_phpunit
  local __path

  if [[ $CI_TYPE == "module" ]]; then
    __path=${CI_WEB_ROOT}/modules/custom/${CI_PROJECT_NAME}/${_ARGS}
  else
    __path=${CI_DOC_ROOT}/${_ARGS}
  fi

  if ! eval "_exist_dir ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output"; then
    printf "%s[NOTICE]%s Create dir %s\\n" "${_dim}" "${_end}" "${BROWSERTEST_OUTPUT_DIRECTORY}"
    _dkexec_bash "mkdir -p ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output"
    _dkexec_bash "chown -R www-data:www-data ${BROWSERTEST_OUTPUT_DIRECTORY} && chmod -R 777 ${BROWSERTEST_OUTPUT_DIRECTORY}"
  fi

  if ! eval "_exist_file /opt/drupal/web/core/phpunit.xml"; then
    if [ -f "$_DIR/../phpunit.xml" ]; then
      printf "%s[NOTICE]%s Using .gitlab-ci/phpunit.xml\\n" "${_dim}" "${_end}"
      _dkexec_bash "cp -u /builds/.gitlab-ci/phpunit.xml /opt/drupal/web/core"
    else
      printf "%s[NOTICE]%s Get remote phpunit.xml\\n" "${_dim}" "${_end}"
      curl -fsSL "${CI_REMOTE_FILES}/phpunit.xml" -o "$_DIR/../phpunit.xml"
      _dkexec_bash "cp -u /builds/.gitlab-ci/phpunit.xml /opt/drupal/web/core"
    fi
  fi

          # --testsuite "${CI_PHPUNIT_TESTS}unit,${CI_PHPUNIT_TESTS}kernel,${CI_PHPUNIT_TESTS}functional,${CI_PHPUNIT_TESTS}functional-javascript" \

  _dkexec sudo -E -u www-data ${CI_DOC_ROOT}/vendor/bin/phpunit \
        --configuration ${CI_WEB_ROOT}/core \
        --testsuite "${CI_PHPUNIT_TESTS}functional-javascript" \
        --verbose
        # ${__path}
}

# Standalone qa test, can set path as argument and tools with option "-qa".
_qa() {

  local __path

  if [[ -n ${_ARGS} ]]; then
    __path=${CI_DOC_ROOT}/${_ARGS}
  else
    __path=${CI_WEB_ROOT}/modules/custom
  fi

  if [ -z "${__tools_qa}" ]; then
    local __tools_qa=${TOOLS_QA}
  fi

  if [ ! -f "$_DIR/../.phpmd.xml" ]; then
    printf "%s[NOTICE]%s Get remote .phpmd.xml\\n" "${_dim}" "${_end}"
    curl -fsSL "$CI_REMOTE_FILES/.phpmd.xml" -o "$_DIR/../.phpmd.xml"
  fi
  if [ ! -f "$_DIR/../.phpqa.yml" ]; then
    printf "%s[NOTICE]%s Get remote .phpqa.yml\\n" "${_dim}" "${_end}"
    curl -fsSL "$CI_REMOTE_FILES/.phpqa.yml" -o "$_DIR/../.phpqa.yml"
  fi
  if [ ! -f "$_DIR/../phpstan.neon" ]; then
    printf "%s[NOTICE]%s Get remote phpstan.neon\\n" "${_dim}" "${_end}"
    curl -fsSL "$CI_REMOTE_FILES/phpstan.neon" -o "$_DIR/../phpstan.neon"
  fi

  printf "%s[NOTICE]%s qa: %s %s\\n" "${_dim}" "${_end}" "${__tools_qa}" "${__path}"

  _dkexec phpqa --tools ${__tools_qa} \
        --config ${CI_PROJECT_DIR}/.gitlab-ci \
        --analyzedDirs ${__path}
}

_lint() {
  if [ $__skip_install = 1 ]; then
    printf "%s[SKIP]%s Yarn install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Yarn\\n""${_dim}" "${_end}"
    docker exec -it ci-drupal \
      yarn --cwd ${CI_WEB_ROOT}/core install
  fi

  printf "\\n%s[INFO]%s Eslint\\n\\n" "${_blu}" "${_end}"
  docker exec -it -w ${CI_WEB_ROOT}/core ci-drupal \
    ${CI_WEB_ROOT}/core/node_modules/.bin/eslint \
      --config ${CI_WEB_ROOT}/core/.eslintrc.passing.json \
      --resolve-plugins-relative-to ${CI_WEB_ROOT}/core/node_modules \
      ${CI_DIRS_JS}

  printf "\\n%s[INFO]%s Stylelint\\n\\n" "${_blu}" "${_end}"
  docker exec -it -w ${CI_WEB_ROOT}/core ci-drupal \
    ${CI_WEB_ROOT}/core/node_modules/.bin/stylelint \
      --config ${CI_WEB_ROOT}/core/.stylelintrc.json \
      --formatter verbose \
      ${CI_DIRS_CSS}

  if ! eval "_exist_file /opt/drupal/twig-lint"; then
    printf "%s[NOTICE]%s Install twig-lint\\n" "${_dim_blu}" "${_end}"
    docker exec -it ci-drupal \
      curl -fsSL https://asm89.github.io/d/twig-lint.phar -o /opt/drupal/twig-lint
  else
    printf "%s[SKIP]%s twig-lint already installed\\n" "${_dim_blu}" "${_end}"
  fi

  printf "\\n%s[INFO]%s Twig lint\\n\\n" "${_blu}" "${_end}"
  docker exec -it ci-drupal \
    php /opt/drupal/twig-lint lint "${CI_DIRS_TWIG}"
}

# Standalone security test.
_security() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n\\n" "${_blu}" "${_end}"

  _dkexec security-checker --path=/opt/drupal/ -format markdown
}

_behat() {
  # Starting Chrome.
  if [[ $(docker exec ci-drupal ps | grep chrome) ]]; then
    printf "%s[NOTICE]%s Chrome already running\\n" "${_dim}" "${_end}"
  else
    printf "%s[NOTICE]%s Start Chrome\\n" "${_dim}" "${_end}"
    docker exec -d ci-drupal /scripts/start-chrome.sh&
    sleep 2s
  fi

  docker exec -t ci-drupal curl -s http://localhost:9222/json/version | jq '.'

  if [ $__skip_install = 1 ]; then
    printf "%s[SKIP]%s Drupal install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Drupal\\n""${_dim}" "${_end}"
    docker exec -it -w ${CI_DOC_ROOT} ci-drupal \
      ${CI_DOC_ROOT}/vendor/bin/drush --root="${CI_WEB_ROOT}" si -y ${CI_BEHAT_INSTALL_PROFILE} --db-url="${SIMPLETEST_DB}"
  fi

  __install_behat

  # _dkexec \
  #   ${CI_DOC_ROOT}/vendor/bin/behat --config ${CI_PROJECT_DIR}/behat_tests/behat.yml \
  #     --format progress \
  #     --out std
}

__install_behat() {
  if ! eval "_exist_file /opt/drupal/vendor/bin/behat"; then
    printf "%s[NOTICE]%s Install Behat\\n" "${_dim_blu}" "${_end}"
    _dkexec composer require -d /opt/drupal --no-ansi -n --dev \
      "drupal/drupal-extension:~4.1" \
      "dmore/behat-chrome-extension:^1.3" \
      "emuse/behat-html-formatter:0.2.*" \
      "friends-of-behat/mink-extension:^2.6";
  else
    printf "%s[SKIP]%s Behat already installed\\n" "${_dim_blu}" "${_end}"
  fi

  if ! eval "_exist_file /opt/drupal/vendor/bin/drush"; then
    printf "%s[NOTICE]%s Install Drush\\n" "${_dim_blu}" "${_end}"
    _dkexec composer require --no-ansi -n drush/drush
  else
    printf "%s[SKIP]%s Drush already installed\\n" "${_dim_blu}" "${_end}"
  fi
}

# Replicate test nightwatch-js .gitlab-ci/.gitlab-ci-template.yml
_nightwatch() {

  if [ $__skip_install = 1 ]; then
    printf "%s[SKIP]%s Yarn install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Yarn\\n""${_dim}" "${_end}"
    docker exec -it ci-drupal \
      yarn --cwd ${CI_WEB_ROOT}/core install
    __version=$(docker exec -t ci-drupal sh -c "google-chrome --product-version | cut -d. -f1")
    _dkexec_bash \
      "yarn --cwd ${CI_WEB_ROOT}/core upgrade chromedriver@$__version"
  fi

  # Log versions.night
  _dkexec_bash \
    "${CI_WEB_ROOT}/core/node_modules/.bin/nightwatch --version"
  _dkexec_bash \
    "${CI_WEB_ROOT}/core/node_modules/.bin/chromedriver --version"
  _dkexec_bash \
    "/usr/bin/google-chrome --version"

  if [ ! -f "$_DIR/../.env" ]; then
    printf "%s[NOTICE]%s Get remote .env\\n" "${_dim}" "${_end}"
    curl -fsSL ${CI_REMOTE_FILES}/.env -o "$_DIR/../.env"
  fi

  docker cp "$_DIR/../.env" ci-drupal:/opt/drupal/web/core/.env

  # Running tests
  # docker exec -it -u root -w ${CI_PROJECT_DIR} ci-drupal \
  #   yarn --cwd ${CI_WEB_ROOT}/core test:nightwatch ${CI_NIGHTWATCH_TESTS}

}

####### Metrics jobs

# _metrics_template() {
#   if [ $__skip_prepare = 1 ]; then
#     printf "%s[SKIP]%s .metrics_template\\n" "${_dim_blu}" "${_end}"
#   else
#     printf "%s[NOTICE]%s Replicate .metrics_template\\n" "${_dim}" "${_end}"

#     # before_script
#     _get_robo_file
#     _do_ci_prepare
#   fi
# }

# _metrics() {
#   printf "\\n%s[INFO]%s Perform job 'Php metrics' (metrics)\\n\\n" "${_blu}" "${_end}"
#   local CI_JOB_NAME="metrics"

#   # @todo: test copy xml files
#   # - cp ./report-phpunit_unit-kernel/*.xml /tmp/ || true
#   # - cp ./report-phpunit_functional/*.xml /tmp/ || true
#   # - cp ./report-phpunit_functionaljs/*.xml /tmp/ || true

#   docker exec -t -w /opt/drupal ci-drupal \
#     phpqa --tools ${CI_TOOLS_METRICS} \
#       --config ${CI_PROJECT_DIR}/.gitlab-ci\
#       --buildDir ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
#       --analyzedDirs '${CI_DIRS_PHP}'
# }

# _copy_output() {
#   _dkexec mkdir -p "${CI_PROJECT_DIR}/report-${1}/browser_output"
#   docker exec -d -w ${CI_PROJECT_DIR} ci-drupal cp -r ${CI_WEB_ROOT}/sites/simpletest/browser_output/ ${CI_PROJECT_DIR}/report-${1}/
#   sleep 1s
#   _clean_browser_output
# }

###############################################################################
# Docker helpers commands.
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    # docker exec -it -w ${CI_PROJECT_DIR} ci-drupal "$@" || true
    docker exec -it ci-drupal "$@" || true
  fi
}

_dkexec_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    # docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
    docker exec -it ci-drupal bash -c "$@"
  fi
}

###############################################################################
# Helpers commands.
###############################################################################

_exist_file() {
  [ $(docker exec -t ci-drupal sh -c "[ -f ${1} ] && echo true") ]
}

_exist_dir() {
  [ $(docker exec -t ci-drupal sh -c "[ -d ${1} ] && echo true") ]
}

_init_variables() {
  _env

  source $__env

  _clean_env
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

  if [ -f "$_DIR/../ci/variables.yml" ]; then
    debug "Use local variables.yml"
    __yaml_variables="$_DIR/../ci/variables.yml"
  elif [ -f "$_DIR/variables.yml" ]; then
    debug "Use local downloaded variables.yml"
    __yaml_variables="$_DIR/variables.yml"
  else
    debug "Use remote variables.yml"
    curl -fsSL "${CI_REMOTE_FILES}/ci/variables.yml" -o "$_DIR/variables.yml"
    __yaml_variables="$_DIR/variables.yml"
  fi

  __yaml_local="$_DIR/.local.yml"
  __env="$_DIR/.env"

  _check_yq

  debug "Generate .env file..."

  CI_PROJECT_DIR="/builds"

  if [ -f $__env ]; then
    rm -f $__env
  fi

  touch $__env

  echo "# This file is auto generated, do not edit." >> $__env
  echo "# To update launch:" >> $__env
  echo "# ${_ME} env" >> $__env

  echo 'CI_PROJECT_NAME: my-project' >> $__env
  echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}" >> $__env

  yq '... comments=""' $__yaml_variables | yq '.[.default_variables]' >> $__env

  # Fix MINK_DRIVER_ARGS_WEBDRIVER, remove spaces and escape \.
  sed -i '/MINK_DRIVER_ARGS_WEBDRIVER/d' $__env
  MINK_DRIVER_ARGS_WEBDRIVER=$(yq '.[.default_variables].MINK_DRIVER_ARGS_WEBDRIVER' $__yaml_variables)
  MINK_DRIVER_ARGS_WEBDRIVER="$(echo -e "${MINK_DRIVER_ARGS_WEBDRIVER}" | tr -d '[:space:]')"
  MINK_DRIVER_ARGS_WEBDRIVER=$(sed 's#\\#\\\\#g' <<< $MINK_DRIVER_ARGS_WEBDRIVER)
  echo '# [fix] Fixed MINK_DRIVER_ARGS_WEBDRIVER' >> $__env
  echo 'MINK_DRIVER_ARGS_WEBDRIVER='${MINK_DRIVER_ARGS_WEBDRIVER} >> $__env

  # Fix BEHAT_PARAMS, remove spaces and escape \.
  sed -i '/BEHAT_PARAMS/d' $__env
  BEHAT_PARAMS=$(yq '.[.default_variables].BEHAT_PARAMS' $__yaml_variables)
  BEHAT_PARAMS="$(echo -e "${BEHAT_PARAMS}" | tr -d '[:space:]')"
  BEHAT_PARAMS=$(sed 's#\\#\\\\#g' <<< $BEHAT_PARAMS)
  echo '# [fix] Fixed BEHAT_PARAMS' >> $__env
  echo 'BEHAT_PARAMS='${BEHAT_PARAMS} >> $__env

  echo '# [fix] Override variables from '$__yaml >> $__env
  yq '... comments=""' $__yaml | yq '.variables' >> $__env

  # Replace variables.
  CI_WEB_ROOT=$(yq '.[.default_variables].CI_WEB_ROOT' $__yaml_variables)
  sed -i "s#\${CI_WEB_ROOT}#${CI_WEB_ROOT}#g" $__env
  echo '# [fix] Replaced CI_WEB_ROOT' >> $__env

  CI_DOC_ROOT=$(yq '.[.default_variables].CI_DOC_ROOT' $__yaml_variables)
  sed -i "s#\${CI_DOC_ROOT}#${CI_DOC_ROOT}#g" $__env
  echo '# [fix] Replaced CI_DOC_ROOT' >> $__env

  SIMPLETEST_DB=$(yq '.[.default_variables].SIMPLETEST_DB' $__yaml_variables)
  sed -i "s#\${SIMPLETEST_DB}#${SIMPLETEST_DB}#g" $__env
  echo '# [fix] Replaced SIMPLETEST_DB' >> $__env

  CI_DB_DRIVER=$(yq '.[.default_variables].CI_DB_DRIVER' $__yaml_variables)
  sed -i "s#\${CI_DB_DRIVER}#${CI_DB_DRIVER}#g" $__env
  echo '# [fix] Replaced CI_DB_DRIVER' >> $__env

  CI_REF=$(yq '.variables.CI_REF' $__yaml)
  sed -i "s#\${CI_REF}#${CI_REF}#g" $__env
  echo '# [fix] Fixed CI_REF' >> $__env
  echo 'CI_IMAGE_REF="'${CI_REF}'"' >> $__env

  CI_DRUPAL_VERSION=$(yq '.variables.CI_DRUPAL_VERSION.value' $__yaml)
  sed -i "s#CI_DRUPAL_VERSION:\(.*\)#CI_DRUPAL_VERSION=${CI_DRUPAL_VERSION}#g" $__env
  echo '# [fix] drupal version' >> $__env

  # Replace some variables by their values from main file.
  CI_DRUPAL_WEB_ROOT=$(yq '.variables.CI_DRUPAL_WEB_ROOT' $__yaml)
  sed -i "s#\${CI_DRUPAL_WEB_ROOT}#${CI_DRUPAL_WEB_ROOT}#g" $__env
  echo '# [fix] Replaced CI_DRUPAL_WEB_ROOT' >> $__env

  if [ -f $__yaml_local ]; then
    echo '# [fix] Local override variables .local.yml' >> $__env
    yq $__yaml_local >> $__env
  fi

  # Fix env file format.
  _yml_to_env_fixes $__env
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

_up() {
  if [ -f "$_DIR/docker-compose.yml" ]; then
    docker compose --project-directory $_DIR -f $_DIR/docker-compose.yml up -d
  else
    printf "%s[ERROR]%s Missing $_DIR/docker-compose.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
  printf "%s[NOTICE]%s Please wait ~10s for DB to be initialized...\\n" "${_dim}" "${_end}"
}

_down() {
  if [ -f "$_DIR/docker-compose.yml" ]; then
    docker compose --project-directory $_DIR -f $_DIR/docker-compose.yml down
  else
    printf "%s[ERROR]%s Missing $_DIR/docker-compose.yml file.\\n" "${_red}" "${_end}"
    exit 1
  fi
}

_reboot() {
  _down
  _up
}

_restart() {
  _down
  _up
}

_check_yq() {
  if ! [ -x "$(command -v yq)" ]; then
    printf "%s[INFO]%s Install missing yq.\\n" "${_dim}" "${_end}"
    curl -fSL https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64 -o ${HOME}/.local/bin/yq && chmod +x ${HOME}/.local/bin/yq
  fi
}

###############################################################################
# Dispatch
###############################################################################

__dispatch() {
  local cmd="_${_CMD}"
  local sub="_${_ARGS}"

  if [ "$(type -t "${cmd}")" == 'function' ]; then
    _init_variables
    $cmd
  else
    if [ ! -z $_ARGS ]; then
      _init_variables
      if [ "$(type -t "${sub}")" == 'function' ]; then
        local pre_cmd="_pre$cmd"
        if [ "$(type -t "${pre_cmd}")" == 'function' ]; then
          $pre_cmd $sub
        fi
        $sub
        local post_cmd="_post$cmd"
        if [ "$(type -t "${post_cmd}")" == 'function' ]; then
          $post_cmd $sub
        fi
      else
        printf "%s[ERROR]%s Unknown argument: %s\\nRun --help for usage.\\n" "${_red}" "${_end}" "${_ARGS}"
      fi
    else
      printf "%s[ERROR]%s Unknown command: %s\\nRun --help for usage.\\n" "${_red}" "${_end}" "${_CMD}"
    fi
  fi
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
    _print_help
    exit 0
  elif [ "${_CMD}" == "env" ]; then
    _init_variables
    exit 0
  fi

  __dispatch

}

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
_print_help() {
  cat <<HEREDOC

  Locally run Gitlab-ci tests with a docker-compose stack.
  Most commands are executed in the ci-drupal container.

  Usage:
    ${_ME} qa

  Standalone local tests (no reports, cli only):
    phpunit                         Run a phpunit test.
    qa                              Run a qa test.
    lint                            Run a lint.
    security                        Run a security test.
    behat                           Run a behat test, if behat_tests folder exist.

  Standalone local options
    -qa|--tools-qa                  Standalone local qa tools, default $TOOLS_QA.
    --skip-install                  Skip install steps (Behat, Lint).

  Options
    -h|--help                       Print help.
HEREDOC
}

###############################################################################
# Error Messages
###############################################################################

# _exit_1()
#
# Usage:
#   _exit_1 <command>
#
# Description:
#   Exit with status 1 after executing the specified command with output
#   redirected to standard error. The command is expected to print a message
#   and should typically be either `echo`, `printf`, or `cat`.
_exit_1() {
  {
    # Prefix die message with "cross mark (U+274C)", often displayed as a red x.
    printf "%s " "$(tput setaf 1)❌$(tput sgr0)"
    "${@}"
  } 1>&2
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
  _exit_1 echo "${@}"
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

# Options ####################################################################

tty=
tty -s && tty=--tty

###############################################################################
# PROGRAMS helpers
###############################################################################

###############################################################################
# __get_option_value()
#
# Usage:
#   __get_option_value <option> <value>
#
# Description:
#  Given a flag (e.g., -e | --example) return the value or exit 1 if value
#  is blank or appears to be another option.
__get_option_value() {
  local __arg="${1:-}"
  local __val="${2:-}"

  if [[ -n "${__val:-}" ]] && [[ ! "${__val:-}" =~ ^- ]]
  then
    printf "%s\\n" "${__val}"
  else
    _exit_1 printf "%s requires a valid argument.\\n" "${__arg}"
  fi
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
__skip_install=0
__tools_qa=""

CI_REMOTE_FILES="https://gitlab.com/mog33/gitlab-ci-drupal/-/raw/4.x-dev/.gitlab-ci"

_CMD=()

while ((${#}))
do
  __arg="${1:-}"
  __val="${2:-}"

  case "${__arg}" in
    -h|--help)
      _PRINT_HELP=1
      ;;
    --debug)
      _USE_DEBUG=1
      ;;
    --debug-fail)
      _USE_DEBUG=1
      trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR
      set -u -e -E -o pipefail
      ;;
    --skip-install)
      __skip_install=1
      ;;
    -qa|--tools-qa)
      __tools_qa="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    --endopts)
      # Terminate option parsing.
      break
      ;;
    -*)
      _exit_1 printf "Unexpected option: %s\\n" "${__arg}"
      ;;
    *)
      _CMD+=("$1")
      ;;
  esac
  shift
done

if [ -z ${_CMD:-} ]; then
  _print_help
  exit 0
fi

_ARGS=${_CMD[@]:1}

# Call `_main` after everything has been defined.
_main
