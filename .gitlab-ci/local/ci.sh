#!/bin/bash
set -e

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.

###############################################################################
# Local only tests, not included in Gtilab ci and more flexible.
#############################################################################&##
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

  _dkexec ${DOC_ROOT}/vendor/bin/phpunit --version
}

# Standalone Phpunit test for local tests, can set path as argument.
# Usage:
#   phpunit web/core/modules/action/tests/src/Unit
_phpunit() {
  __install_phpunit
  local __path

  if [[ $CI_TYPE == "module" ]]; then
    __path=${WEB_ROOT}/modules/custom/${CI_PROJECT_NAME}/${_ARGS}
  else
    __path=${DOC_ROOT}/${_ARGS}
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

  if docker exec ci-drupal ps | grep chromedriver; then
    printf "%s[NOTICE]%s Chromedriver running\\n" "${_dim}" "${_end}"
  else
    printf "%s[NOTICE]%s Start Chromedriver\\n" "${_dim}" "${_end}"
    docker exec -d ci-drupal /scripts/start-chromedriver.sh
    sleep 2s
  fi

  _dkexec sudo -E -u www-data ${DOC_ROOT}/vendor/bin/phpunit \
        --configuration ${WEB_ROOT}/core \
        --verbose --debug \
        ${__path}
}

# Standalone qa test, can set path as argument and tools with option "-qa".
_qa() {

  local __path

  if [[ -n ${_ARGS} ]]; then
    __path=${DOC_ROOT}/${_ARGS}
  else
    __path=${WEB_ROOT}/modules/custom
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
      yarn --cwd ${WEB_ROOT}/core install
  fi

  printf "\\n%s[INFO]%s Eslint\\n\\n" "${_blu}" "${_end}"
  docker exec -it -w ${WEB_ROOT}/core ci-drupal \
    ${WEB_ROOT}/core/node_modules/.bin/eslint \
      --config ${WEB_ROOT}/core/.eslintrc.passing.json \
      --resolve-plugins-relative-to ${WEB_ROOT}/core/node_modules \
      ${DIRS_JS}

  printf "\\n%s[INFO]%s Stylelint\\n\\n" "${_blu}" "${_end}"
  docker exec -it -w ${WEB_ROOT}/core ci-drupal \
    ${WEB_ROOT}/core/node_modules/.bin/stylelint \
      --config ${WEB_ROOT}/core/.stylelintrc.json \
      --formatter verbose \
      ${DIRS_CSS}

  if ! eval "_exist_file /opt/drupal/twig-lint"; then
    printf "%s[NOTICE]%s Install twig-lint\\n" "${_dim_blu}" "${_end}"
    docker exec -it ci-drupal \
      curl -fsSL https://asm89.github.io/d/twig-lint.phar -o /opt/drupal/twig-lint
  else
    printf "%s[SKIP]%s twig-lint already installed\\n" "${_dim_blu}" "${_end}"
  fi

  printf "\\n%s[INFO]%s Twig lint\\n\\n" "${_blu}" "${_end}"
  docker exec -it ci-drupal \
    php /opt/drupal/twig-lint lint "${DIRS_TWIG}"
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
    docker exec -it -w ${DOC_ROOT} ci-drupal \
      ${DOC_ROOT}/vendor/bin/drush --root="${WEB_ROOT}" si -y ${BEHAT_INSTALL_PROFILE} --db-url="${SIMPLETEST_DB}"
  fi

  __install_behat

  # _dkexec \
  #   ${DOC_ROOT}/vendor/bin/behat --config ${CI_PROJECT_DIR}/behat_tests/behat.yml \
  #     --format progress \
  #     --out std
}

__install_behat() {
  if ! eval "_exist_file /opt/drupal/vendor/bin/behat"; then
    printf "%s[NOTICE]%s Install Behat\\n" "${_dim_blu}" "${_end}"
    _dkexec composer require -d /opt/drupal --no-ansi -n \
      "drupal/drupal-extension:~4.1" \
      "dmore/behat-chrome-extension:^1.3" \
      "bex/behat-screenshot:^2.1" \
      "emuse/behat-html-formatter:0.2.*"
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
      yarn --cwd ${WEB_ROOT}/core install
    __version=$(docker exec -t ci-drupal sh -c "google-chrome --product-version | cut -d. -f1")
    _dkexec_bash \
      "yarn --cwd ${WEB_ROOT}/core upgrade chromedriver@$__version"
  fi

  # Log versions.night
  _dkexec_bash \
    "${WEB_ROOT}/core/node_modules/.bin/nightwatch --version"
  _dkexec_bash \
    "${WEB_ROOT}/core/node_modules/.bin/chromedriver --version"
  _dkexec_bash \
    "/usr/bin/google-chrome --version"

  if [ ! -f "$_DIR/../.env" ]; then
    printf "%s[NOTICE]%s Get remote .env\\n" "${_dim}" "${_end}"
    curl -fsSL ${CI_REMOTE_FILES}/.env -o "$_DIR/../.env"
  fi

  docker cp "$_DIR/../.env" ci-drupal:/opt/drupal/web/core/.env

  # Running tests
  # docker exec -it -u root -w ${CI_PROJECT_DIR} ci-drupal \
  #   yarn --cwd ${WEB_ROOT}/core test:nightwatch ${NIGHTWATCH_TESTS}

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
#     phpqa --tools ${TOOLS_METRICS} \
#       --config ${CI_PROJECT_DIR}/.gitlab-ci\
#       --buildDir ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
#       --analyzedDirs '${DIRS_PHP}'
# }

# _copy_output() {
#   _dkexec mkdir -p "${CI_PROJECT_DIR}/report-${1}/browser_output"
#   docker exec -d -w ${CI_PROJECT_DIR} ci-drupal cp -r ${WEB_ROOT}/sites/simpletest/browser_output/ ${CI_PROJECT_DIR}/report-${1}/
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

  # Remove quotes on NIGHTWATCH_TESTS.
  sed -i 's#NIGHTWATCH_TESTS="\(.*\)"#NIGHTWATCH_TESTS=\1#g' $__env

  source $__env

  # Fixes post source, for a proper docker config.
  if [ -f "$_DIR/../ci/variables_test.yml" ]; then
    debug "Use local variables_test.yml"
    __yaml_variables_test="$_DIR/../ci/variables_test.yml"
  elif [ -f "$_DIR/variables_test.yml" ]; then
    debug "Use local downloaded variables_test.yml"
    __yaml_variables_test="$_DIR/variables_test.yml"
  else
    debug "Use remote variables_test.yml"
    curl -fsSL "${CI_REMOTE_FILES}/ci/variables_test.yml" -o "$_DIR/variables_test.yml"
    __yaml_variables_test="$_DIR/variables_test.yml"
  fi

  # CHROME_OPTS can be local and needs no quotes so cannot be sourced.
  local __chrome_opts
  if [ -f $__yaml_local ]; then
    __chrome_opts=$(yq r $__yaml_local "CHROME_OPTS")
  fi
  if [[ -z ${__chrome_opts} ]]; then
    __chrome_opts=$(yq r $__yaml_variables_test "[.variables_test].variables.CHROME_OPTS")
  fi
  echo "CHROME_OPTS=${__chrome_opts}" >> $__env

  _clean_env
}

_clean_env() {
  if [ -f "$_DIR/variables.yml" ]; then
    rm -f "$_DIR/variables.yml"
  fi
  if [ -f "$_DIR/variables_test.yml" ]; then
    rm -f "$_DIR/variables_test.yml"
  fi
}

_env() {

  if [ -f "$_DIR/../../starter.gitlab-ci.yml" ]; then
    __yaml="$_DIR/../../starter.gitlab-ci.yml"
  elif [ -f "$_DIR/../../.gitlab-ci.yml" ]; then
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

  if [ -f "$_DIR/../ci/variables_test.yml" ]; then
    debug "Use local variables_test.yml"
    __yaml_variables_test="$_DIR/../ci/variables_test.yml"
  elif [ -f "$_DIR/variables_test.yml" ]; then
    debug "Use local downloaded variables_test.yml"
    __yaml_variables_test="$_DIR/variables_test.yml"
  else
    debug "Use remote variables_test.yml"
    curl -fsSL "${CI_REMOTE_FILES}/ci/variables_test.yml" -o "$_DIR/variables_test.yml"
    __yaml_variables_test="$_DIR/variables_test.yml"
  fi

  __yaml_local="$_DIR/.local.yml"
  __env="$_DIR/.env"

  _check_yq

  debug "Generate .env file..."

  WEB_ROOT=$(yq r $__yaml_variables "[.default_variables].WEB_ROOT")
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

  yq r $__yaml_variables "[.default_variables]" >> $__env
  yq r $__yaml_variables_test "[.variables_test].variables" >> $__env


  # Fix MINK_DRIVER_ARGS_WEBDRIVER, remove spaces and escape \.
  sed -i '/MINK_DRIVER_ARGS_WEBDRIVER/d' $__env
  MINK_DRIVER_ARGS_WEBDRIVER=$(yq r $__yaml_variables_test "[.variables_test].variables.MINK_DRIVER_ARGS_WEBDRIVER")
  MINK_DRIVER_ARGS_WEBDRIVER="$(echo -e "${MINK_DRIVER_ARGS_WEBDRIVER}" | tr -d '[:space:]')"
  MINK_DRIVER_ARGS_WEBDRIVER=$(sed 's#\\#\\\\#g' <<< $MINK_DRIVER_ARGS_WEBDRIVER)
  echo '# Fixed MINK_DRIVER_ARGS_WEBDRIVER' >> $__env
  echo 'MINK_DRIVER_ARGS_WEBDRIVER='${MINK_DRIVER_ARGS_WEBDRIVER} >> $__env

  # Fix BEHAT_PARAMS, remove spaces and escape \.
  sed -i '/BEHAT_PARAMS/d' $__env
  BEHAT_PARAMS=$(yq r $__yaml_variables "[.default_variables].BEHAT_PARAMS")
  BEHAT_PARAMS="$(echo -e "${BEHAT_PARAMS}" | tr -d '[:space:]')"
  BEHAT_PARAMS=$(sed 's#\\#\\\\#g' <<< $BEHAT_PARAMS)
  echo '# Fixed BEHAT_PARAMS' >> $__env
  echo 'BEHAT_PARAMS='${BEHAT_PARAMS} >> $__env

  # Replace variables.
  CI_REF=$(yq r $__yaml_variables "[.default_variables].CI_REF")
  sed -i "s#\${CI_REF}#${CI_REF}#g" $__env
  echo '# Fixed CI_REF' >> $__env

  echo '# Override variables' >> $__env
  yq r $__yaml "variables" >> $__env
  sed -i '/^extends:/d' $__env

  if [ -f $__yaml_local ]; then
    echo '# Local variables' >> $__env
    yq r $__yaml_local >> $__env
  fi

  # Replace some variables by their values.
  sed -i "s#\${WEB_ROOT}#${WEB_ROOT}#g" $__env
  echo '# Replaced WEB_ROOT' >> $__env

  # CHROME_OPTS needs no quotes so cannot be sourced.
  sed -i '/CHROME_OPTS/d' $__env
  echo '# Deleted CHROME_OPTS for sourced' >> $__env

  # Fix env file format.
  _yml_to_env_fixes $__env
}

_yml_to_env_fixes() {
  __env_file="${1}"
  # Delete lines starting with spaces.
  sed -i '/^ /d' $__env
  # Replace : by =.
  sed -i 's#: #=#g' $__env_file
  # Treat 1 / 0 options without double quotes.
  sed -i 's#"1"#1#g' $__env_file
  sed -i 's#"0"#0#g' $__env_file
  # Remove quotes on CI_DRUPAL_VERSION.
  sed -i 's#CI_DRUPAL_VERSION="\(.*\)"#CI_DRUPAL_VERSION=\1#g' $__env_file
  # Add quotes on Nightwatch tests and Chrome opts.
  sed -i 's#NIGHTWATCH_TESTS=\(.*\)#NIGHTWATCH_TESTS="\1"#g' $__env_file
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

CI_REMOTE_FILES="https://gitlab.com/mog33/gitlab-ci-drupal/-/raw/3.x-dev/.gitlab-ci"

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
