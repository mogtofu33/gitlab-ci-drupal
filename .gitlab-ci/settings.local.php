<?php

// This file is used when installing Drupal from an existing database dump.

$settings['hash_salt'] = 'CI_ONLY_HASH_SALT_NOT_SAFE_!!!!';

$settings["config_sync_directory"] = getenv('DOC_ROOT') . '/config/sync';

$databases['default']['default'] = [
  'database' => 'drupal',
  'username' => 'drupal',
  'password' => 'drupal',
  // 'prefix' => '',
  'host' => 'db',
  'port' => getenv('SERVICE_DATABASE_PORT'),
  'namespace' => 'Drupal\\Core\\Database\\Driver\\' . getenv('DB_DRIVER'),
  'driver' => getenv('DB_DRIVER'),
];

// https://www.drupal.org/project/drupal/issues/2867042
$settings['file_chmod_directory'] = 02775;
