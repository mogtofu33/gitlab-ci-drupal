<?php

$settings['hash_salt'] = 'not_safe_salt_just_for_ci';
$settings['update_free_access'] = FALSE;
$settings['container_yamls'][] = $app_root . '/' . $site_path . '/services.yml';
$settings['file_scan_ignore_directories'] = [
  'node_modules',
  'bower_components',
];
$settings['entity_update_batch_size'] = 50;

$config_directories['sync'] = '../config/sync';

$databases['default']['default'] = array (
  'database' => 'drupal',
  'username' => 'root',
  'password' => '',
  'prefix' => '',
  'host' => 'mariadb',
  // 'host' => 'pgsql',
  'port' => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  // 'namespace' => 'Drupal\\Core\\Database\\Driver\\pgsql',
  'driver' => 'mysql',
  // 'driver' => 'pgsql',
);

# https://www.drupal.org/project/drupal/issues/2867042
$settings['file_chmod_directory'] = 02775;
