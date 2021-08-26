#!/usr/bin/env bash

# Simple basic script for CI to install Drupal from a DB dump or with Drush.

function install() {
  local profile=${1:-"minimal"}

  local files="${WEB_ROOT}/sites/default/files"
  local filename="${CI_PROJECT_DIR}/dump/dump-${CI_DRUPAL_VERSION}_${profile}.sql"

  mkdir -p $files
  chown www-data:www-data $files
  chmod 777 $files

  echo -e "\033[1;36mInstalling Drupal with profile ${profile}...\033[1;37m"

  if [ -f "${filename}.gz" ]; then
    zcat "${filename}.gz" > $filename
  fi

  if [ -f "${filename}" ]; then
    echo -e "\033[1;36mImport dump $filename\033[1;37m"
    mysql -hmariadb -uroot drupal < ${filename}
    # When install from dump we need to be sure settings.php is correct.
    cp -u ${CI_PROJECT_DIR}/.gitlab-ci/settings.local.php ${WEB_ROOT}/sites/default/

    rm -f ${WEB_ROOT}/sites/default/settings.php
    cp ${WEB_ROOT}/sites/default/default.settings.php ${WEB_ROOT}/sites/default/settings.php
    echo 'include $app_root . "/" . $site_path . "/settings.local.php";' >> ${WEB_ROOT}/sites/default/settings.php
  else
    echo -e "\033[1;36mNo dump found for $filename, install Drupal with Drush.\033[1;37m"
    if [ ! -f "${DOC_ROOT}/vendor/bin/drush" ]; then
      composer require --no-ansi -n --dev drush/drush
    fi
    ${DOC_ROOT}/vendor/bin/drush site:install $profile --yes --db-url=${SIMPLETEST_DB}
  fi

  if [ -f "${DOC_ROOT}/vendor/bin/drush}" ]; then
    ${DOC_ROOT}/vendor/bin/drush status --fields="bootstrap"
  fi
}

install "${@}"
