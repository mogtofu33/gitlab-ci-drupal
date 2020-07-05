#!/bin/bash
set -e

# This script is an helper to run some tests from Gitlab-ci config in a local
# environment with docker-compose.

###############################################################################
# Local only tests, not included in Gtilab ci and more flexible.
###############################################################################

# Standalone Phpunit test for local tests, can set path as argument.
_phpunit() {
  local __path=${WEB_ROOT}

  if [ $CI_TYPE == "module" ]; then
    local __path=${WEB_ROOT}/modules/custom/${CI_PROJECT_NAME}/${_ARGS}
  fi

  _dkexec \
    ${DOC_ROOT}/vendor/bin/phpunit \
        --configuration ${WEB_ROOT}/core \
        --verbose --debug \
        ${__path}
}

# Standalone qa test, can set path as argument and tools with option "-qa".
_qa() {

  if [ -z $__local_path ]; then
    local __local_path=${DIRS_QA}
  else
    local __local_path=${WEB_ROOT}/modules/custom/${CI_PROJECT_NAME}
  fi
  if [ -z $__tools_qa ]; then
    local __tools_qa=${TOOLS_QA}
  fi

  printf "%s[NOTICE]%s qa: %s %s\\n" "${_dim}" "${_end}" "${__tools_qa}" "${__local_path}"

  # script
  docker exec -it -w ${DOC_ROOT} ci-drupal \
    phpqa --tools ${__tools_qa} \
        --config ${CI_PROJECT_DIR}/.gitlab-ci \
        --buildDir ${CI_PROJECT_DIR}/report-qa \
        --analyzedDirs ${__local_path}
}

###############################################################################
# Replicate gitlab-ci for local tests
###############################################################################

####### Build
# Replicate .gitlab-ci/ci/template.01_build.yml
_build_template() {

  # before_script
  # @todo: composer / yarn repository and yarn registry.
  # @todo: ssh key for private repository.
  printf "%s[NOTICE]%s composer/yarn registry and ssh key not yet supported!\\n" "${_dim}" "${_end}"

  # after_script
  _get_robo_file

  if [ $__skip_build = 1 ]; then
    printf "%s[SKIP]%s ci:build\\n" "${_dim_blu}" "${_end}"
  else
    docker exec -it -w /var/www/html ci-drupal robo ci:build
  fi

  _do_ci_prepare

  # _create_artifacts
}

# Replicate Build job .gitlab-ci/.gitlab-ci-template.yml
_build() {
  local CI_JOB_NAME="build"

  printf "%s[NOTICE]%s replicate build\\n" "${_dim}" "${_end}"
  _build_template

  # script
  if [ ${CI_TYPE} == "project" ]; then
    if ! $(_exist_file /var/www/html/composer.json); then
      docker exec -it -w /var/www/html ci-drupal \
        composer validate --no-check-all --no-check-publish -n --no-ansi
    fi

    if [ $__skip_build = 1 ]; then
      printf "%s[SKIP]%s composer install \\n" "${_dim_blu}" "${_end}"
    else
      if $(_exist_file /var/www/html/composer.json); then
        docker exec -it -w /var/www/html ci-drupal \
          composer install --no-ansi -n --prefer-dist
      else
        printf "%s[SKIP]%s No composer.json found.\\n" "${_dim_blu}" "${_end}"
      fi
    fi
  fi

  if [ $__skip_build = 1 ]; then
    printf "%s[SKIP]%s install drupal/core-dev:^%s \\n" "${_dim_blu}" "${_end}" "${CI_DRUPAL_VERSION}"
  else
    if ! $(_exist_file /var/www/html/vendor/bin/phpunit); then
      docker exec -it -w /var/www/html ci-drupal \
        composer require --no-ansi -n drupal/core-dev:^${CI_DRUPAL_VERSION}
      _dkexec /var/www/html/vendor/bin/phpunit --version
    else
      printf "%s[SKIP]%s Phpunit already installed\\n" "${_dim_blu}" "${_end}"
    fi
  fi

  if [ ${CI_TYPE} == "project" ]; then
    if [ $__skip_build = 1 ]; then
      printf "%s[SKIP]%s install behat/drush\\n" "${_dim_blu}" "${_end}"
    else
      if ! $(_exist_file /var/www/html/vendor/bin/behat); then
        _dkexec \
        COMPOSER_MEMORY_LIMIT=-1 composer require -d /var/www/html --no-ansi -n --no-suggest \
          "bex/behat-screenshot:^1.2" \
          "dmore/behat-chrome-extension:^1.3" \
          "emuse/behat-html-formatter:0.1.*" \
          "drupal/drupal-extension:~4.1"
      else
        printf "%s[SKIP]%s Behat already installed\\n" "${_dim_blu}" "${_end}"
      fi

      if ! $(_exist_file /var/www/html/vendor/bin/drush); then
        docker exec -it -w /var/www/html ci-drupal \
          composer require --no-ansi -n --no-suggest drush/drush
      else
        printf "%s[SKIP]%s Drush already installed\\n" "${_dim_blu}" "${_end}"
      fi
    fi
  fi
}

####### Tests jobs

# Replicate .gitlab-ci/ci/template.02_test.yml
_test_template() {
  if [ $__skip_prepare = 1 ]; then
    printf "%s[SKIP]%s .test_template\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s Replicate .test_template\\n" "${_dim}" "${_end}"

    # before_script
    # Apache launch is entrypoint, so no need to launch it locally.
    # docker exec -d ci-drupal bash -c "apache2-foreground"

    _get_robo_file
    _do_ci_prepare

    docker exec -t ci-drupal bash -c \
      'mkdir -p ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output'
    docker exec -t ci-drupal bash -c \
      'chmod -R 777 ${BROWSERTEST_OUTPUT_DIRECTORY}'
    docker exec -t ci-drupal bash -c \
      'chown -R www-data:www-data ${BROWSERTEST_OUTPUT_DIRECTORY}'
  fi
}

# Replicate test unit-kernel .gitlab-ci/.gitlab-ci-template.yml
_unit_kernel() {
  printf "\\n%s[INFO]%s Perform job 'Unit and kernel tests' (unit-kernel)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="phpunit_unit-kernel"

  # script
  _dkexec mkdir -p report-${CI_JOB_NAME}/coverage-xml report-${CI_JOB_NAME}/coverage-html

  _dkexec \
    ${DOC_ROOT}/vendor/bin/phpunit --testsuite ${PHPUNIT_TESTS}unit,${PHPUNIT_TESTS}kernel \
        --configuration ${WEB_ROOT}/core \
        --coverage-xml ${CI_PROJECT_DIR}/report-${CI_JOB_NAME}/coverage-xml \
        --coverage-html ${CI_PROJECT_DIR}/report-${CI_JOB_NAME}/coverage-html \
        --coverage-clover ${CI_PROJECT_DIR}/report-${CI_JOB_NAME}/coverage.xml \
        --coverage-text \
        --colors=never \
        --testdox-html report-${CI_JOB_NAME}/phpunit.html \
        --log-junit report-${CI_JOB_NAME}/junit-unit-kernel.xml \
        --verbose --debug

  # after_script
  # if [ ! -z ${CODECOV_TOKEN} ] && [ -f "report-${CI_JOB_NAME}/coverage.xml" ]; then
  #   bash <(curl -s https://codecov.io/bash) -f "report-${CI_JOB_NAME}/coverage.xml" || true;
  # fi
}

# Replicate test functional .gitlab-ci/.gitlab-ci-template.yml
_functional() {
  printf "\\n%s[INFO]%s Perform job 'Functional' (functional)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="phpunit_functional"

  # Not in gitlab-ci.yml
  # Specific to run a local test as apache.
  _dkexec \
    mkdir -p "${CI_PROJECT_DIR}/report-${CI_JOB_NAME}"
  _dkexec \
    chown -R www-data:www-data "${CI_PROJECT_DIR}/report-${CI_JOB_NAME}"
  ########################################

  # script
  _dkexec \
    sudo -E -u www-data ${DOC_ROOT}/vendor/bin/phpunit --testsuite ${PHPUNIT_TESTS}functional \
        --configuration ${WEB_ROOT}/core \
        --log-junit report-${CI_JOB_NAME}/junit-functional.xml \
        --testdox-html report-${CI_JOB_NAME}/phpunit.html \
        --verbose --debug

  # after_script
  _copy_output "${CI_JOB_NAME}"
}

# Replicate test functional-javascript .gitlab-ci/.gitlab-ci-template.yml
_functional_js() {
  printf "\\n%s[INFO]%s Perform job 'Functional Js' (functional_js)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="phpunit_functionaljs"

  # script
  if ((_USE_DEBUG)); then
    docker exec -t ci-drupal /scripts/start-chromedriver.sh
  else
    docker exec -d ci-drupal /scripts/start-chromedriver.sh
  fi
  sleep 2s

  docker exec -t ci-drupal curl -s http://localhost:9515/status | jq '.'

  _dkexec \
    ${DOC_ROOT}/vendor/bin/phpunit --testsuite ${PHPUNIT_TESTS}functional-javascript \
        --configuration ${WEB_ROOT}/core \
        --log-junit report-${CI_JOB_NAME}/junit-functionaljs.xml \
        --testdox-html report-${CI_JOB_NAME}/phpunit.html \
        --verbose --debug

  # after_script
  _copy_output "${CI_JOB_NAME}"
}

# Replicate test nightwatch-js .gitlab-ci/.gitlab-ci-template.yml
_nightwatchjs() {
  printf "\\n%s[INFO]%s Perform job 'Nightwatch Js' (nightwatch)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="nightwatchjs"

  # script
  if [ $__skip_build = 1 ]; then
    printf "%s[SKIP]%s build (yarn install) \\n" "${_dim_blu}" "${_end}"
  else

    _dkexec_bash \
      "touch 3017176.patch
      if [ ${CI_DRUPAL_VERSION} == \"8.8\" ]; then
        curl -fsSL https://www.drupal.org/files/issues/2019-11-11/3017176-16.patch -o 3017176.patch || true
      fi
      patch -d ${WEB_ROOT} -N -p1 < 3017176.patch || true"

    _dkexec_bash \
      "yarn --cwd ${WEB_ROOT}/core install"

    _dkexec_bash \
      "yarn --cwd ${WEB_ROOT}/core upgrade chromedriver@$(google-chrome --product-version | cut -d. -f1)"

    # Cleanup extra step.
    _dkexec_bash \
      "rm -f 3017176.patch"
  fi

  _dkexec_bash \
    "mkdir -p ${CI_PROJECT_DIR}/report-${CI_JOB_NAME}"

  # Log versions.
  _dkexec_bash \
    "${WEB_ROOT}/core/node_modules/.bin/nightwatch --version"
  _dkexec_bash \
    "${WEB_ROOT}/core/node_modules/.bin/chromedriver --version"
  _dkexec_bash \
    "/usr/bin/google-chrome --version"

  # Running tests
  _dkexec_bash \
    "yarn --cwd ${WEB_ROOT}/core test:nightwatch ${NIGHTWATCH_TESTS} \
      --output_folder ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
      --detailed_output false"

  # after_script
  _dkexec_bash \
    "yarn --cwd ${WEB_ROOT}/core add nightwatch-html-reporter"

  _dkexec_bash \
    "${WEB_ROOT}/core/node_modules/.bin/nightwatch-html-reporter \
          --report-dir ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
          --output nightwatch.html \
          --browser false \
          --theme outlook"

}

# Replicate test security-checker .gitlab-ci/.gitlab-ci-template.yml
_security() {
  printf "\\n%s[INFO]%s Perform job 'Security report' (security_checker)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="security-checker"

  _dkexec \
    security-checker security:check /var/www/html/composer.lock --no-ansi 2>&1 | tee report-${CI_JOB_NAME}/security.txt
}

# Replicate test behat .gitlab-ci/.gitlab-ci-template.yml
_behat() {
  printf "\\n%s[INFO]%s Perform job 'Behat' (behat)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="behat"

  # script

  # Starting Chrome.
  if [ $__skip_prepare = 1 ]; then
    printf "%s[SKIP]%s prepare (start-chrome.sh)\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s Start chrome %s\\n""${_dim}" "${_end}" "${1}"
    docker exec -d ci-drupal /scripts/start-chrome.sh&
    sleep 2s
  fi

  docker exec -t ci-drupal curl -s http://localhost:9222/json/version | jq '.'

  # _dkexec_bash \
    # ${CI_PROJECT_DIR}/.gitlab-ci/install_drupal.sh ${BEHAT_INSTALL_PROFILE}
  if [ $__skip_install = 1 ]; then
    printf "%s[SKIP]%s install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Drupal %s\\n""${_dim}" "${_end}" "${1}"
    _dkexec \
      ${DOC_ROOT}/vendor/bin/drush --root="${WEB_ROOT}" si -y ${BEHAT_INSTALL_PROFILE} --db-url="${SIMPLETEST_DB}"
  fi

  docker exec -it -w ${WEB_ROOT} ci-drupal \
    ${DOC_ROOT}/vendor/bin/behat --config ${CI_PROJECT_DIR}/behat_tests/behat.yml \
      --format progress \
      --out std \
      --format junit \
      --out ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
      --format html \
      --out ${CI_PROJECT_DIR}/report-${CI_JOB_NAME}

}

# Replicate test pa11y .gitlab-ci/.gitlab-ci-template.yml
_pa11y() {
  printf "\\n%s[INFO]%s Perform job 'Pa11y' (pa11y)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="accessibility_pa11y"

  # script
  # _dkexec_bash \
    # ${CI_PROJECT_DIR}/.gitlab-ci/install_drupal.sh ${PA11Y_INSTALL_PROFILE}
  if [ $__skip_install = 1 ]; then
    printf "%s[SKIP]%s install\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s install Drupal %s\\n""${_dim}" "${_end}" "${1}"
    _dkexec \
      ${DOC_ROOT}/vendor/bin/drush --root="${WEB_ROOT}" si -y ${PA11Y_INSTALL_PROFILE} --db-url="${SIMPLETEST_DB}"
  fi

  if [ $__skip_build = 1 ]; then
    printf "%s[SKIP]%s build (yarn add pa11y-ci) \\n" "${_dim_blu}" "${_end}"
  else
    docker exec -it -w ${WEB_ROOT} ci-drupal \
      yarn --cwd ${WEB_ROOT}/core add pa11y-ci
  fi

  docker exec -it -w ${WEB_ROOT} ci-drupal \
    ${WEB_ROOT}/core/node_modules/.bin/pa11y-ci --config ${CI_PROJECT_DIR}/.gitlab-ci/pa11y-ci.json

  # after_script:
  _dkexec \
    mkdir -p "${CI_PROJECT_DIR}/report-${CI_JOB_NAME}" && cp pa11y*.png "${CI_PROJECT_DIR}/report-${CI_JOB_NAME}"
}

####### QA jobs

_qa_template() {
  if [ $__skip_prepare = 1 ]; then
    printf "%s[SKIP]%s .qa_template\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s Replicate .qa_template\\n" "${_dim}" "${_end}"

    # before_script
    _get_robo_file
    _do_ci_prepare

  fi
}

_php_qa() {
  printf "\\n%s[INFO]%s Perform job 'PHP QA' (php_qa)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="php-qa"

  # script
  docker exec -it -w ${DOC_ROOT} ci-drupal \
    phpqa --tools ${TOOLS_QA} \
        --config ${CI_PROJECT_DIR}/.gitlab-ci \
        --buildDir ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
        --analyzedDirs ${DIRS_QA}
}

####### Lint jobs

_lint_template() {
  if [ $__skip_prepare = 1 ]; then
    printf "%s[SKIP]%s .lint_template\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s Replicate .lint_template\\n" "${_dim}" "${_end}"

    # before_script
    _get_robo_file
    _do_ci_prepare

    docker exec -it ci-drupal \
      yarn --cwd ${WEB_ROOT}/core install
  fi
}

_lint_js() {
  printf "\\n%s[INFO]%s Perform job 'Js lint' (eslint)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="lint_js"

  # script
  docker exec -it -w ${WEB_ROOT}/core ci-drupal \
    ${WEB_ROOT}/core/node_modules/.bin/eslint \
      --config ${WEB_ROOT}/core/.eslintrc.passing.json \
      --format html --output-file "${CI_PROJECT_DIR}/report-${CI_JOB_NAME}/eslint.html" \
      ${DIRS_JS}
}

_lint_css() {
  printf "\\n%s[INFO]%s Perform job 'Css lint' (stylelint)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="lint_css"

  # script
  # _dkexec mkdir -p ${WEB_ROOT}/core
  # _dkexec curl -fsSL https://git.drupalcode.org/project/drupal/raw/${CI_DRUPAL_VERSION}.x/core/.stylelintrc.json -o ${WEB_ROOT}/core/.stylelintrc.json

  # printf "%s[NOTICE]%s Install Stylelint-formatter-pretty\\n" "${_dim}" "${_end}"
  # docker exec -it -w /var/www/html ci-drupal \
      # robo install:stylelint-formatter-pretty

  # _dkexec_core_bash "${WEB_ROOT}/core/node_modules/.bin/stylelint\
  #   --config-basedir ${WEB_ROOT}/core/node_modules/ \
  #   --custom-formatter ${WEB_ROOT}/core/node_modules/stylelint-formatter-pretty \
  #   --config ${WEB_ROOT}/core/.stylelintrc.json \${CSS_FILES}"

  docker exec -it -w ${WEB_ROOT}/core ci-drupal \
    ${WEB_ROOT}/core/node_modules/.bin/stylelint \
      --config ${WEB_ROOT}/core/.stylelintrc.json \
      --formatter verbose \
      ${DIRS_CSS}
}

_lint_twig() {
  printf "\\n%s[INFO]%s Perform job 'Twig lint' (twiglint)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="lint_twig"

  docker exec -it ci-drupal \
    curl -fsSL https://asm89.github.io/d/twig-lint.phar -o twig-lint
  
  docker exec -it ci-drupal \
    php twig-lint lint "${DIRS_TWIG}"
}

####### Metrics jobs

_metrics_template() {
  if [ $__skip_prepare = 1 ]; then
    printf "%s[SKIP]%s .metrics_template\\n" "${_dim_blu}" "${_end}"
  else
    printf "%s[NOTICE]%s Replicate .metrics_template\\n" "${_dim}" "${_end}"

    # before_script
    _get_robo_file
    _do_ci_prepare
  fi
}

_metrics() {
  printf "\\n%s[INFO]%s Perform job 'Php metrics' (metrics)\\n\\n" "${_blu}" "${_end}"
  local CI_JOB_NAME="metrics"

  # @todo: test copy xml files
  # - cp ./report-phpunit_unit-kernel/*.xml /tmp/ || true
  # - cp ./report-phpunit_functional/*.xml /tmp/ || true
  # - cp ./report-phpunit_functionaljs/*.xml /tmp/ || true

  docker exec -t -w /var/www/html ci-drupal \
    phpqa --tools ${TOOLS_METRICS} \
      --config ${CI_PROJECT_DIR}/.gitlab-ci\
      --buildDir ${CI_PROJECT_DIR}/report-${CI_JOB_NAME} \
      --analyzedDirs '${DIRS_PHP}'
}

################################################################################
# Replicate .gitlab-ci/ci/template.artifacts.yml
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
        /var/www/html/vendor /var/www/html/web ${WEB_ROOT}/core/node_modules \
        /var/www/html/drush /var/www/html}/scripts /var/www/html/composer.json \
        /var/www/html/composer.lock /var/www/html/.env.example /var/www/html/load.environment.php
      docker cp ci-drupal:/tmp/artifacts.tgz ./tmp/
    else
      printf "%s[SKIP]%s Artifact already exist.\\n" "${_dim_blu}" "${_end}"
    fi
  fi
}

_copy_output() {
  _dkexec mkdir -p "${CI_PROJECT_DIR}/report-${1}/browser_output"
  docker exec -d -w ${CI_PROJECT_DIR} ci-drupal cp -r ${WEB_ROOT}/sites/simpletest/browser_output/ ${CI_PROJECT_DIR}/report-${1}/
  sleep 1s
  _clean_browser_output
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

_dkexec_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${CI_PROJECT_DIR} ci-drupal bash -c "$@"
  fi
}

_dkexec_core_bash() {
  if ! [ -f "/.dockerenv" ]; then
    if ((_USE_DEBUG)); then debug "$FUNCNAME called by ${FUNCNAME[1]}"; echo "$@"; fi
    docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "$@"
  fi
}

###############################################################################
# Helpers commands.
###############################################################################

_get_robo_file() {
  printf "%s[NOTICE]%s Get RoboFile\\n" "${_dim}" "${_end}"
  if [ -f "$_DIR/../RoboFile.php" ]; then
    _dkexec_bash "cp -u /builds/RoboFile.php /var/www/html/"
  else
    _dkexec_bash "curl -fsSL ${CI_REMOTE_FILES}/RoboFile.php -o RoboFile.php"
    _dkexec_bash "cp -u RoboFile.php /var/www/html/"
  fi
}

_do_ci_prepare() {
  if [ $__skip_prepare = 1 ]; then
    printf "%s[SKIP]%s ci:prepare\\n" "${_dim_blu}" "${_end}"
  else
    if [ $__skip_config = 1 ]; then
      printf "%s[SKIP]%s ci:get-config-files\\n" "${_dim_blu}" "${_end}"
      docker exec -it -w /var/www/html ci-drupal robo ci:prepare 0
    else
      docker exec -it -w /var/www/html ci-drupal robo ci:prepare
    fi
  fi
}

_clean_robo_file() {
  printf "%s[NOTICE]%s Clean RoboFile\\n" "${_dim}" "${_end}"
  docker exec -t ci-drupal bash -c \
    'rm -f /builds/RoboFile.php /var/www/html/RoboFile.php /var/www/html/web/*/custom/*/RoboFile.php'
}

_exist_file() {
  [ $(docker exec -t ci-drupal sh -c "[ -f ${1} ] && echo true") ]
}

_exist_dir() {
  [ $(docker exec -t ci-drupal sh -c "[ -d ${1} ] && echo true") ]
}

_test_site() {
  if [ ${_ARGS} == "install" ]; then
    docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "sudo -u www-data php ./scripts/test-site.php install --setup-file 'core/tests/Drupal/TestSite/TestSiteInstallTestScript.php' --install-profile 'demo_umami' --base-url http://localhost --db-url mysql://root@mariadb/drupal"
  else
    docker exec -it -w ${WEB_ROOT}/core ci-drupal bash -c "sudo -u www-data php ./scripts/test-site.php ${_ARGS}"
  fi
}

_set_dev_mode() {
  printf "\\n%s[INFO]%s Set dev mode\\n\\n" "${_blu}" "${_end}"
  docker exec -it -w /var/www/html ci-drupal \
    composer require drupal/console drupal/devel drupal/devel_php
  docker exec -it -w ${WEB_ROOT} ci-drupal \
    /var/www/html/vendor/bin/drupal site:mode dev
}

_init_variables() {
  _env

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

  # CHROME_OPTS needs no quotes so cannot be sourced.
  CHROME_OPTS=$(yq r $__yaml_variables_test "[.variables_test].variables.CHROME_OPTS")
  echo "CHROME_OPTS=${CHROME_OPTS}" >> $__env

  # Remove quotes on NIGHTWATCH_TESTS.
  sed -i 's#NIGHTWATCH_TESTS="\(.*\)"#NIGHTWATCH_TESTS=\1#g' $__env

  _clean_env
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
  echo "# ${_ME} run" >> $__env

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

  echo '# Local variables' >> $__env
  if [ -f $__yaml_local ]; then
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

_test_chrome() {
  if ! $(_exist_file /usr/bin/google-chrome); then
    printf "%s[ERROR]%s Missing Google Chrome!\\n" "${_red}" "${_end}"
    exit 1
  fi
  docker exec -t ci-drupal google-chrome --version
}

_restart() {
  _clean_job_reports
  _clean_build
  _down
  _up
}

_up() {
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

_clean_build() {
  printf "%s[NOTICE]%s Build clean %s job\\n" "${_dim}" "${_end}" "${1:-"all"}"
  # _dkexec_bash "rm -rf ${WEB_ROOT} /var/www/html/vendor"
  _clean_robo_file
}

_clean_job_reports() {
  printf "%s[NOTICE]%s Clean %s job\\n" "${_dim}" "${_end}" "${1:-"all"}"
  _clean_browser_output
  docker exec -it ci-drupal rm -rf /builds/report-${1:-"*"}
  
}

_clean_browser_output() {
  docker exec -t ci-drupal bash -c \
    'rm -rf ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output'
  docker exec -t ci-drupal bash -c \
    'mkdir -p ${BROWSERTEST_OUTPUT_DIRECTORY}/browser_output'
  docker exec -t ci-drupal bash -c \
    'chmod -R g+s ${BROWSERTEST_OUTPUT_DIRECTORY}'
  docker exec -t ci-drupal bash -c \
    'chown -R www-data:www-data ${BROWSERTEST_OUTPUT_DIRECTORY}'
}

_check_yq() {
  if ! [ -x "$(command -v yq)" ]; then
    curl -fsSL https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
  fi
}

###############################################################################
# Commands to reference group of commands.
###############################################################################

_pre_test() {
  printf "%s[NOTICE]%s _pre_test\n" "${_dim}" "${_end}"
  _clean_job_reports ${1}
  # Dependencies: build
  _build
  _test_template
}
_post_test() {
  printf "%s[NOTICE]%s _pre_test\n" "${_dim}" "${_end}"
  _clean_build
}

_pre_qa() {
  printf "%s[NOTICE]%s _pre_qa\n" "${_dim}" "${_end}"
  _clean_job_reports ${1}
  _qa_template
}
_post_qa() {
  printf "%s[NOTICE]%s _post_qa\n" "${_dim}" "${_end}"
}

_pre_lint() {
  printf "%s[NOTICE]%s _pre_lint\n" "${_dim}" "${_end}"
  _clean_job_reports ${1}
  _lint_template
}
_post_lint() {
  printf "%s[NOTICE]%s _post_lint\n" "${_dim}" "${_end}"
}

_pre_metrics() {
  printf "%s[NOTICE]%s _pre_metrics\n" "${_dim}" "${_end}"
  _clean_job_reports ${1}
  _metrics_template
}
_post_metrics() {
  printf "%s[NOTICE]%s _post_metrics\n" "${_dim}" "${_end}"
}

__dispatch() {
  local cmd="_${_CMD}"
  local sub="_${_ARGS}"

  if [ "$(type -t "${cmd}")" == 'function' ]; then
    _init_variables
    # _init_stack
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
    _help
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
_help() {
  cat <<HEREDOC

Locally run Gitlab-ci tests with a docker-compose stack.
Most commands are executed in the ci-drupal container.

Usage:
  ${_ME} all

Arguments with option for ci:
  test                            Run a test, ie: test unit_kernel
  qa                              Run a QA, ie: test php_qa
  lint                            Run a Lint, ie: lint lint_css

  Standalone ci tests:
    security
    unit_kernel
    functional
    functional_js
    nightwatchjs
    behat
    pa11y
    php_qa
    lint_js
    lint_css
    lint_twig

Standalone local tests (no reports, cli only):
  phpunit                         Run a phpunit test.
  qa                              Run a qa test.

Standalone local options
  -qa|--tools-qa                 Standalone local qa tools, default $TOOLS_QA.
  -d|--dir                       Standalone local dir, default $DIRS_QA.

Options
  -h|--help                       Print help.
  -sp|--skip-prepare              Skip prepare step (copy files, set folders).
  -sb|--skip-build                Skip build step (cache, perform build).
  -sc|--skip-config               Skip config files step.
  -si|--skip-install              Skip Drupal install step (behat, pay11c).
  -sa|-skip-all                   Skip build, prepare and install.
  -sim|--simulate                 Robo simulate action.
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

###############################################################################
# PROGRAMS helpers
###############################################################################

###############################################################################
# _require_argument()
#
# Usage:
#   _require_argument <option> <argument>
#
# If <argument> is blank or another option, print an error message and  exit
# with status 1.
_require_argument() {
  # Set local variables from arguments.
  #
  # NOTE: 'local' is a non-POSIX bash feature and keeps the variable local to
  # the block of code, as defined by curly braces. It's easiest to just think
  # of them as local to a function.
  local _option="${1:-}"
  local _argument="${2:-}"

  if [[ -z "${_argument}" ]] || [[ "${_argument}" =~ ^- ]]
  then
    _die printf "Option requires a argument: %s\\n" "${_option}"
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
__skip_prepare=0
__skip_config=0
__skip_build=0
__skip_install=0
__drupal_profile="minimal"
__tools_qa=""
__local_path=""

CI_REMOTE_FILES="https://gitlab.com/mog33/gitlab-ci-drupal/-/raw/2.x-dev/.gitlab-ci"

_CMD=()

while [[ ${#} -gt 0 ]]
do
  __option="${1:-}"
  __maybe_param="${2:-}"
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
    -sc|--skip-config)
      printf "%s[NOTICE]%s skip get ci config\\n" "${_dim}" "${_end}"
      __skip_config=1
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
    -qa|--tools-qa)
      _require_argument "${__option}" "${__maybe_param}"
      __tools_qa="${__maybe_param}"
      shift
      ;;
    -d|--dir)
      _require_argument "${__option}" "${__maybe_param}"
      __local_path="${__maybe_param}"
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

if [ -z $_CMD ]; then
  _PRINT_HELP=1
fi

_ARGS=${_CMD[@]:1}

# Call `_main` after everything has been defined.
_main
