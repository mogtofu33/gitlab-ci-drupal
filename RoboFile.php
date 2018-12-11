<?php

// @codingStandardsIgnoreStart

/**
 * Base tasks for setting up a module to test within a full Drupal environment.
 *
 * This file expects to be called from the root of a Drupal site.
 *
 * @class RoboFile
 * @codeCoverageIgnore
 */

use Robo\Tasks;

/**
 * Robofile with tasks for CI.
 */
class RoboFile extends Tasks {

  /**
   * Database connection information.
   *
   * @var string
   *   The database URL. This can be overridden by specifying a $DB_URL
   *   environment variable.
   */
  protected $dbUrl = 'mysql://root@mariadb/drupal';

  /**
   * Database dump.
   *
   * @var string
   *   A database dump file for CI.
   */
  protected $dbDump = 'dump/dump.sql';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder. This can be overridden by specifying a $WEB_ROOT
   *   environment variable.
   */
  protected $webRoot = 'web';

  /**
   * RoboFile constructor.
   */
  public function __construct() {
    // Pull a DB_URL from the environment, if it exists.
    if (filter_var(getenv('DB_URL'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('DB_URL');
    }
    // Pull a WEB_ROOT from the environment, if it exists.
    if (filter_var(getenv('WEB_ROOT'), FILTER_VALIDATE_URL)) {
      $this->webRoot = getenv('WEB_ROOT');
    }
    // Treat this command like bash -e and exit as soon as there's a failure.
    $this->stopOnFail();
  }

  /**
   * Updates Composer dependencies.
   */
  public function updateDependencies() {
    // The git checkout includes a composer.lock, and running Composer update
    // on it fails for the first time.
    $this->taskFilesystemStack()->remove('composer.lock')->run();
    $this->taskComposerUpdate()
      ->optimizeAutoloader()
      ->run();
  }

  /**
   * Install Vanilla Drupal 8 with Composer template.
   */
  public function downloadDrupal() {
    if (!file_exists('drupal/web/index.php')) {
      $this->taskComposerCreateProject()
        ->source('drupal-composer/drupal-project:8.x-dev')
        ->target('drupal')
        ->preferDist()
        ->noInteraction()
        ->ignorePlatformRequirements()
        ->run();
    }
    else {
      $this->say("drupal folder exist, skip.");
    }
    #$this->_deleteDir('drupal');
  }

  /**
   * Install Drupal from a composer.json file.
   */
  public function installDrupal() {
    $this->taskComposerInstall()
      ->preferDist()
      ->noInteraction()
      ->ignorePlatformRequirements()
      ->run();
  }

  /**
   * Install Drupal.
   *
   * @param string $profile
   *   (optional) The Drupal profile name, default to minimal.
   */
  public function setupDrupal($profile = 'minimal') {

    $task = $this->drush()
      ->args('site-install', $profile)
      ->option('yes')
      ->option('db-url', $this->dbUrl, '=');

    // Sending email will fail, so we need to allow this to always pass.
    $this->stopOnFail(FALSE);
    $task->run();
    $this->stopOnFail();

    $this->dumpDrupal();
  }

  /**
   * Dump Drupal DB for CI.
   */
  public function dumpDrupal() {
    $this->drush()
      ->args('sql-dump')
      ->option('result-file', 'dump/dump.sql', '=')
      ->run();
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  protected function drush() {
    // Drush needs an absolute path to the docroot.
    $docroot = $this->getDocroot() . '/' . $this->webRoot;
    return $this->taskExec('vendor/bin/drush')
      ->option('root', $docroot, '=');
  }

  /**
   * Get the absolute path to the docroot.
   *
   * @return string
   *   The absolute path.
   */
  protected function getDocroot() {
    $docroot = (getcwd());
    return $docroot;
  }

  /**
   * Run PHPUnit and simpletests for the module.
   *
   * @param string $module
   *   The module name.
   */
  public function test($module) {
    $this->phpUnit($module)
      ->run();
  }

  /**
   * Return a configured phpunit task.
   *
   * This will check for PHPUnit configuration first in the module directory.
   * If no configuration is found, it will fall back to Drupal's core
   * directory.
   *
   * @param string $module
   *   The module name.
   *
   * @return \Robo\Task\Testing\PHPUnit
   */
  private function phpUnit($module) {
    return $this->taskPhpUnit('vendor/bin/phpunit')
      ->option('verbose')
      ->option('debug')
      ->configFile($this->webRoot . '/core')
      ->group($module);
  }

}
