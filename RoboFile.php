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
   * Drupal coding standards for Code Sniffer (phpcs) are provided by Coder.
   *
   * @var string
   *   The coder url to download.
   */
  protected $coderUrl = 'https://ftp.drupal.org/files/projects/coder-8.x-3.1.tar.gz';

  /**
   * Phpmetrics to check Php code.
   *
   * @var string
   *   The phpmetroics phar url to download.
   */
  protected $phpmetricsUrl = 'https://github.com/phpmetrics/PhpMetrics/releases/download/v2.4.1/phpmetrics.phar';

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
   * Installs Coder without composer.
   */
  public function installCoder() {
    $filename = 'coder.tar.gz';
    $this->downloadFile($filename, $this->coderUrl);

    if (!file_exists('coder/coder_sniffer/Drupal/autoload.php')) {
      $this->taskExtract($filename)
        ->to($this->getDocroot() . '/coder')
        ->run();
    }
    else {
      $this->say('Coder already installed.');
    }
  }

  /**
   * Installs Phpmetrics without composer.
   */
  public function installPhpmetrics() {
    $filename = 'phpmetrics.phar';
    $this->downloadFile($filename, $this->phpmetricsUrl);

    $this->taskFilesystemStack()
      ->chmod('phpmetrics.phar', '755')
      ->run();
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
   * @param string $adminUser
   *   (optional) The administrator's username.
   * @param string $adminPassword
   *   (optional) The administrator's password.
   * @param string $siteName
   *   (optional) The Drupal site name.
   * @param string $profile
   *   (optional) The Drupal profile name, default to minimal.
   */
  public function setupDrupal($adminUser = NULL, $adminPassword = NULL, $siteName = NULL, $profile = 'minimal') {

    $task = $this->drush()
      ->args('site-install', $profile)
      ->option('yes')
      ->option('db-url', $this->dbUrl, '=');

    if ($adminUser) {
      $task->option('account-name', $adminUser, '=');
    }

    if ($adminPassword) {
      $task->option('account-pass', $adminPassword, '=');
    }

    if ($siteName) {
      $task->option('site-name', $siteName, '=');
    }

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
   * Helper to download a file.
   *
   * @param string $filename
   *   The filename, obviously.
   * @param string $url
   *   The file url to download.
   */
  protected function downloadFile($filename, $url) {
    if (!file_exists($filename)) {
      $this->say("Download $filename...");
      $data = file_get_contents($url, FALSE, NULL);
      file_put_contents($filename, $data);
    }
    else {
      $this->say("$filename already exist, skip.");
    }
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
