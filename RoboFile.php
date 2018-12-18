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
   *   A database dump file for CI. This can be overridden by specifying a
   *   $DB_DUMP environment variable. This must be relative to root.
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
    // Pull a DB_DUMP from the environment, if it exists.
    if (filter_var(getenv('DB_DUMP'), FILTER_VALIDATE_URL)) {
      $this->dbDump = getenv('DB_DUMP');
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
      ->noInteraction()
      ->noAnsi()
      ->ignorePlatformRequirements()
      ->option('no-suggest')
      ->option('profile')
      ->run();
  }

  /**
   * Install Vanilla Drupal 8 project with Composer.
   *
   * @param null|string $dest
   *   (optional) The destination to copy the downloaded drupal.
   */
  public function downloadDrupalProject($dest = null) {
    if (!file_exists('drupal/web/index.php')) {
      $this->taskComposerCreateProject()
        ->source('drupal-composer/drupal-project:8.x-dev')
        ->target('drupal')
        ->preferDist()
        ->noInteraction()
        ->ignorePlatformRequirements()
        ->option('profile')
        ->run();
    }
    else {
      $this->say("drupal folder exist, skip create-project.");
    }

    if ($dest) {
      $this->_copyDir('drupal', $dest);
    }
  }

  /**
   * Install Drupal from a composer.json file.
   */
  public function installDrupal() {
    $this->taskComposerInstall()
      ->preferDist()
      ->noInteraction()
      ->noAnsi()
      ->ignorePlatformRequirements()
      ->option('no-suggest')
      ->option('profile')
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
    $this->stopOnFail(false);
    $task->run();
    $this->stopOnFail();

    $this->dumpDrupal();
  }

  /**
   * Check Drupal.
   *
   * @return string
   *   Drupal boostrap result.
   */
  public function checkDrupal() {
    return $this->drush()
      ->args('status')
      ->option('field', 'bootstrap', '=')
      ->run();
  }

  /**
   * Install Drupal from config in ../config/sync.
   */
  public function setupDrupalFromConfig() {

    $task = $this->drush()
      ->args('site-install', 'config_installer')
      ->arg('config_installer_sync_configure_form.sync_directory="../config/sync"')
      ->option('yes')
      ->option('db-url', $this->dbUrl, '=')
      ->run();

    // Sending email will fail, so we need to allow this to always pass.
    $this->stopOnFail(false);
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
      ->option('result-file', $this->getDocroot() . '/' . $this->dbDump, '=')
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
   * Return drupal console with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drupal console exec command.
   */
  protected function drupal_console() {
    // Drush needs an absolute path to the docroot.
    $docroot = $this->getDocroot() . '/' . $this->webRoot;
    return $this->taskExec('vendor/bin/drupal')
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
  public function test($module = null) {
    $this->phpUnit($module)
      ->run();
  }

  /**
   * Run PHPUnit Unit and Kernel for the testsuite or module.
   *
   * @param string $testsuite
   *  (optional)  The testsuite names, separated by commas.
   *
   * @param string $report
   *   (optional) Report dir, relative to root, without trailing slash.
   *
   * @param nbool $xml
   *   (optional) Add coverage xml report (--log-junit).
   *
   * @param bool $html
   *   (optional) Add coverage html report (--testdox-html).
   *
   * @param string $module
   *   (optional) The module name.
   */
  public function testSuite($testsuite = 'unit,kernel', $report = '', $xml = true, $html = true, $module = null) {
    $test = $this->phpUnit($module, $testsuite);
    if ($xml) {
      $test->xml($report . '/phpunit.xml');
    }
    if ($html) {
      $test->option('testdox-html', $report . '/phpunit.html');
    }
    $test->run();
  }

  /**
   * Run PHPUnit code coverage for the testsuite or module.
   *
   * @param string $testsuite
   *  (optional)  The testsuite names, separated by commas.
   *
   * @param string $report
   *   (optional) Report dir, relative to root, without trailing slash.
   *
   * @param nbool $xml
   *   (optional) Add coverage xml report (--coverage-xml).
   *
   * @param bool $html
   *   (optional) Add coverage html report (--coverage-html).
   *
   * @param bool $text
   *   (optional) Add coverage text (--coverage-text). Force disabling colors
   *   (--colors never).
   *
   * @param string $module
   *   (optional) The module name.
   */
  public function testCoverage($testsuite = 'unit,kernel', $report = '', $xml = true, $html = true, $text = true, $module = null) {
    $test = $this->phpUnit($module, $testsuite);
    if ($xml) {
      $test->option('coverage-xml', $report . '/coverage-xml');
    }
    if ($html) {
      $test->option('coverage-html', $report . '/coverage-html');
    }
    if ($text) {
      $test->option('coverage-text')
        ->option('colors', 'never', '=');
    }
    $test->run();
  }

  /**
   * Return a configured phpunit task.
   *
   * This will check for PHPUnit configuration first in the module directory.
   * If no configuration is found, it will fall back to Drupal's core
   * directory.
   *
   * @param string $module
   *   (optional) The module name.
   *
   * @param string $testsuite
   *   (optional) The testsuite names, separated by commas.
   *
   * @return \Robo\Task\Testing\PHPUnit
   */
  private function phpUnit($module = null, $testsuite = null) {
    $task = $this->taskPhpUnit('vendor/bin/phpunit')
      ->option('verbose')
      // ->option('debug')
      ->configFile($this->webRoot . '/core');

    if ($module) {
      $task->group($module);
    }

    if ($testsuite) {
      $task->option('testsuite', $testsuite);
    }
  
    return $task;
  }

}
