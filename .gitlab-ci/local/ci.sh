#!/bin/bash

# set -ex
set -eE -o functrace

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.

###############################################################################
# Docker helpers commands.
###############################################################################

_dkexec() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then
      debug "$FUNCNAME called by ${FUNCNAME[1]}"
      debug "$@"
    fi
    # docker exec -it -w ${CI_PROJECT_DIR} ci-drupal "$@" || true
    docker exec -it ci-drupal "$@" || true
  fi
}

_dkexec_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then
      debug "$FUNCNAME called by ${FUNCNAME[1]}"
      debug "$@"
    fi
    # docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
    docker exec -it ci-drupal bash -c "$@"
  fi
}

_dkexec_drupal_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then
      debug "$FUNCNAME called by ${FUNCNAME[1]}"
      debug "$@"
    fi
    # docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
    docker exec -it -w /opt/drupal/ ci-drupal bash -c "$@"
  fi
}

_dk_running() {
  if [ ! "$(docker ps -a -q -f name=ci-drupal)" ]; then
    if [ ! "$(docker ps -aq -f status=exited -f name=ci-drupal)" ]; then
      printf "%s[ERROR]%s Stack is not running, please do '%s up'.\\n" "${_red}" "${_end}" "${_ME}"
      exit 1
    fi
  else
    printf "%s[ERROR]%s Stack is not running, please do '%s up'.\\n" "${_red}" "${_end}" "${_ME}"
    exit 1
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
  _init_variables
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
# Dispatch Command
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

  if ((_PRINT_HELP)); then
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
  _DIR="$(cd -P "$(dirname "$_SOURCE")" && pwd)"
  _SOURCE="$(readlink "$_SOURCE")"
  [[ $_SOURCE != /* ]] && _SOURCE="$_DIR/$_SOURCE" # if $_SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
_DIR="$(cd -P "$(dirname "$_SOURCE")" && pwd)"

IFS=$'\n\t'

source $_DIR/_commands.sh

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

  Standalone local tests:
    up                              Set stack up for tests.
    build                           Run ci build.
    phpunit                         Run all phpunit tests.
    unit                            Run phpunit unit tests.
    kernel                          Run phpunit kernel tests.
    func                            Run phpunit functional tests.
    funcjs                          Run phpunit functional javascript tests.
    qa                              Run all qa tests.
    phpcs                           Run phpcs.
    phpmd                           Run phpmd.
    phpstan                         Run phpstan.
    lint                            Run a lint.
    security                        Run a security test.
    behat                           Run a behat test, if behat_tests folder exist.

  Standalone local options
    -si | --skip-install            Skip install steps (Behat).
    -se | --skip-env                Skip local env creation.

  Options
    -h|--help                       Print help.
    -v|--verbose                    Verbose output.
    --debug                         Debug output.
    --debug-fail                    Debug stop on error.
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
  if [[ "${_USE_DEBUG:-"0"}" -eq 1 ]]; then
    __DEBUG_COUNTER=$((__DEBUG_COUNTER + 1))
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

  if [[ -n "${__val:-}" ]] && [[ ! "${__val:-}" =~ ^- ]]; then
    printf "%s\\n" "${__val}"
  else
    _exit_1 printf "%s requires a valid argument.\\n" "${__arg}"
  fi
}

# Program Options #############################################################

_red=$'\e[1;31m'
_gre=$'\e[1;32m'
_yel=$'\e[1;33m'
_blu=$'\e[1;34m'
_pur=$'\e[1;35m'
_blu_l=$'\e[1;36m'

_dim=$'\e[2;37m'
_dim_blu=$'\e[2;34m'
_end=$'\e[0m'

# Parse Options ###############################################################

if [ -f "$_DIR/.env.dist" ]; then
  # shellcheck disable=SC1091
  source "$_DIR/.env.dist"
fi
if [ -f "$_DIR/.env.local" ]; then
  # shellcheck disable=SC1091
  source "$_DIR/.env.local"
fi

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0
_VERBOSE=0

# Initialize additional expected option variables.
_SKIP_INSTALL=0
_SKIP_ENV=0

_CMD=()

while ((${#})); do
  __arg="${1:-}"
  __val="${2:-}"

  case "${__arg}" in
  -h | --help)
    _PRINT_HELP=1
    ;;
  -v | --verbose)
    _VERBOSE=1
    ;;
  --debug)
    _USE_DEBUG=1
    ;;
  --debug-fail)
    _USE_DEBUG=1
    trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR
    set -u -e -E -o pipefail
    ;;
  -si | --skip-install)
    _SKIP_INSTALL=1
    ;;
  -se | --skip-env)
    _SKIP_ENV=1
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
