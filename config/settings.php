<?php

$settings['hash_salt'] = '3UL8Ex5rP_ZgBh-ZaQ_PgQ6CTzdWXBWWviBsrobVTLxEAA6H2kvtBkYaUNkZq--LmvV-h0M_6w';
$settings['update_free_access'] = FALSE;
$settings['container_yamls'][] = $app_root . '/' . $site_path . '/services.yml';
$settings['file_scan_ignore_directories'] = [
  'node_modules',
  'bower_components',
];
$settings['entity_update_batch_size'] = 50;

$settings['install_profile'] = 'standard';
$config_directories['sync'] = '../config/sync';

$databases['default']['default'] = array (
  'database' => 'drupal8',
  'username' => 'root',
  'password' => '',
  'prefix' => '',
  'host' => 'mariadb',
  'port' => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
);
