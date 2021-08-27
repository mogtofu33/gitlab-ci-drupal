<?php

$settings['hash_salt'] = 'CI_ONLY_HASH_SALT_NOT_SAFE_!!!!';

$settings["config_sync_directory"] = '/opt/drupal/config/sync';

$databases['default']['default'] = [
  'database' => 'drupal',
  'username' => 'root',
  'password' => '',
  'prefix' => '',
  'host' => 'mariadb',
  'port' => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
];

// https://www.drupal.org/project/drupal/issues/2867042
$settings['file_chmod_directory'] = 02775;
