<?php

// @codingStandardsIgnoreStart

/**
 * Base tasks for setting up a module to test within a full Drupal environment.
 *
 * This file expects to be called from the root of a Drupal site.
 *
 * @class RoboFile
 * @codeCoverageIgnore
 * @SuppressWarnings(PHPMD)
 */

use GuzzleHttp\Client;

/**
 * Robofile with tasks for CI.
 */
class RoboFile extends \Robo\Tasks {

  protected $verbose = false;
  protected $noAnsi = false;

  /**
   * Database connection information.
   *
   * @var string
   *   The database URL. This can be overridden by specifying a $DB_URL or a
   *   $SIMPLETEST_DB environment variable.
   */
  protected $dbUrl = 'mysql://drupal:drupal@mariadb/drupal';

  /**
   * Database dump.
   *
   * @var string
   *   A database dump folder. This can be overridden by specifying a $DB_DUMP
   *   environment variable.
   */
  protected $dbDump = 'dump';

  /**
   * Drupal docroot folder.
   *
   * @var string
   *   The docroot folder. This can be overridden by specifying a $DOC_ROOT
   *   environment variable.
   */
  protected $docRoot = '/var/www/html';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder. This can be overridden by specifying a $WEB_ROOT
   *   environment variable.
   */
  protected $webRoot = '/var/www/html';

  /**
   * Install Drupal.
   *
   * @var bool
   *   Flag to install Drupal. This can be  overridden by specifying an
   *   $INSTALL_DRUPAL environment variable.
   */
  protected $installDrupal = null;

  /**
   * Drupal setup profile.
   *
   * @var string
   *   The profile name.
   */
  protected $setupProfile = 'minimal';

  /**
   * Drupal setup from config.
   *
   * @var bool
   *   Is Drupal setup regular or from config.
   */
  protected $setupFromConfig = false;

  /**
   * Report dir.
   *
   * @var string
   *   The report dir. This can be overridden by specifying a $REPORT_DIR
   *   environment variable.
   */
  protected $reportDir = 'reports';

  /**
   * CI context type.
   *
   * @var string
   *   The type name, as project, custom, module or theme.
   */
  protected $ciType = 'module';

  /**
   * CI_PROJECT_DIR context.
   *
   * @var string
   *   The CI dir, look at env values for This can be  overridden by specifying
   *   a $CI_PROJECT_DIR environment variable.
   */
  protected $ciProjectDir = '';

  /**
   * CI_PROJECT_NAME context.
   *
   * @var string
   *   The CI project name, look at env values for This can be 
   *   overridden by specifying a $CI_PROJECT_NAME environment variable.
   */
  protected $ciProjectName = "my_project";

  /**
   * RoboFile constructor.
   */
  public function __construct() {
    // Treat this command like bash -e and exit as soon as there's a failure.
    $this->stopOnFail();

    if (getenv('VERBOSE')) {
      $this->verbose = getenv('VERBOSE');
    }
    if (getenv('NO_ANSI')) {
      $this->noAnsi = getenv('NO_ANSI');
    }

    // Pull CI variables from the environment, if it exists.
    if (getenv('CI_TYPE')) {
      $this->ciType = getenv('CI_TYPE');
    }
    if (getenv('CI_PROJECT_DIR')) {
      $this->ciProjectDir = getenv('CI_PROJECT_DIR');
    }
    if (getenv('CI_PROJECT_NAME')) {
      $this->ciProjectName = getenv('CI_PROJECT_NAME');
    }

    // Pull a DB_URL from the environment, if it exists.
    if (filter_var(getenv('DB_URL'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('DB_URL');
    }
    // Pull a SIMPLETEST_DB from the environment, if it exists.
    if (filter_var(getenv('SIMPLETEST_DB'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('SIMPLETEST_DB');
    }

    // Pull a DB_DUMP from the environment, if it exists.
    if (getenv('DB_DUMP')) {
      $this->dbDump = getenv('DB_DUMP');
    }
    // Pull a DOC_ROOT from the environment, if it exists.
    if (getenv('DOC_ROOT')) {
      $this->docRoot = getenv('DOC_ROOT');
    }
    // Pull a WEB_ROOT from the environment, if it exists.
    if (getenv('WEB_ROOT')) {
      $this->webRoot = getenv('WEB_ROOT');
    }

    // Pull a REPORT_DIR from the environment, if it exists.
    if (getenv('REPORT_DIR')) {
      $this->reportDir = getenv('REPORT_DIR');
    }
    // Pull a INSTALL_DRUPAL from the environment, if it exists.
    if (getenv('INSTALL_DRUPAL')) {
      $this->installDrupal = getenv('INSTALL_DRUPAL');
    }

  }

  /**
   * Updates Composer dependencies.
   */
  public function updateDependencies($dir = null) {
    if (!$dir) {
      $dir = $this->docRoot;
    }
    // The git checkout includes a composer.lock, and running Composer update
    // on it fails for the first time.
    $this->taskFilesystemStack()->remove('composer.lock')->run();
    $task = $this->taskComposerUpdate()
      ->optimizeAutoloader()
      ->noInteraction()
      ->ignorePlatformRequirements()
      ->option('no-suggest')
      ->option('profile');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    if ($this->noAnsi) {
      $task->noAnsi();
    }
    $task->run();
  }

  /**
   * Download Drupal 8 project with Composer.
   */
  public function downloadDrupalProject($replace = true, $destination = NULL) {

    $tempnam = tempnam(sys_get_temp_dir(), 'drupal.');
    $archive = $tempnam . '.zip';

    if (!$destination) {
      $destination = $this->docRoot;
    }
    $tmp_destination = $destination. '/drupal';

    $client =  new Client();
    $remote = 'https://github.com/drupal-composer/drupal-project/archive/8.x.zip';

    // Get and save file
    $this->say('Downloading Drupal 8 project...');
    $client->get($remote, ['save_to' => $archive]);

    if (file_exists($archive)) {
      if (file_exists($tmp_destination)) {
        $this->taskFilesystemStack()
          ->remove($tmp_destination)
          ->run();
      }
      $this->taskExtract($archive)
        ->to($tmp_destination)
        ->run();

      # Replace existing Drupal.
      if ($replace) {
        $this->taskFilesystemStack()
          // ->remove($destination)
          // ->mkdir($destination)
          ->mirror($tmp_destination, $destination)
          ->run();
      }

    }
    else {
      $this->io()->warning('Failed to download Drupal project!');
    }
  }

  /**
   * Install Vanilla Drupal 8 project with Composer.
   */
  public function createDrupalProject($destination = null) {
    if (!$destination) {
      $destination = $this->docRoot();
    }
    if (file_exists($destination)) {
      $this->taskFilesystemStack()
        ->remove($destination)
        ->mkdir($destination)
        ->run();
    }
    $task = $this->taskComposerCreateProject()
      ->source('drupal-composer/drupal-project:8.x-dev')
      ->target($destination)
      ->preferDist()
      ->noInteraction()
      ->ignorePlatformRequirements()
      ->option('profile');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    if ($this->noAnsi) {
      $task->noAnsi();
    }
    $task->run();
  }

  /**
   * Download Drupal from a composer.json file.
   */
  public function composerInstall($dir = null) {
    if (!$dir) {
      $dir = $this->docRoot;
    }
    $task = $this->taskComposerInstall()
      ->workingDir($dir)
      ->preferDist()
      ->noInteraction()
      ->ignorePlatformRequirements()
      ->option('no-suggest')
      ->option('profile');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    if ($this->noAnsi) {
      $task->noAnsi();
    }
    $task->run();
  }

  /**
   * Install Drupal from a composer.json file.
   */
  public function installDrupal() {
    $this->say('Installing Drupal...');

    if (file_exists($this->dbDump . '/dump.sql')) {
      $this->say("Import dump $this->dbDump/dump.sql");
      $this->_exec('mysql -hmariadb -udrupal -pdrupal drupal < ' . $this->dbDump . '/dump.sql;');
    }
    else {
      $this->setupDrupal();
      $this->dumpDrupal();
    }
    $this->checkDrupal();
  }

  /**
   * Install Drupal from profile or config with config_installer.
   */
  public function setupDrupal() {
    $this->say('Setup Drupal...');

    if ($this->setupFromConfig) {
      $task = $this->drush()
        ->args('site-install', 'config_installer')
        ->arg('config_installer_sync_configure_form.sync_directory="../config/sync"')
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=')
        ->run();
    }
    else {
      $task = $this->drush()
        ->args('site-install', $this->setupProfile)
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=');
    }

    // Sending email will fail, so we need to allow this to always pass.
    $this->stopOnFail(false);
    $task->run();
    $this->stopOnFail();
  }

  /**
   * Check Drupal.
   *
   * @return string
   *   Drupal bootstrap result.
   */
  public function checkDrupal() {
    return $this->drush()
      ->args('status')
      ->option('field', 'bootstrap', '=')
      ->run();
  }

  /**
   * Status of Drupal.
   *
   * @return string
   *   Drupal bootstrap result.
   */
  public function checkDrush() {
    $this->ensureDrush();
  }

  /**
   * Dump Drupal DB.
   */
  public function dumpDrupal() {
    if (!file_exists($this->dbDump)) {
      $this->taskFilesystemStack()->mkdir($this->dbDump)->run();
    }
    $this->drush()
      ->args('sql-dump')
      ->option('result-file', $this->dbDump . '/dump.sql', '=')
      ->run();
  }

  /**
   * Run PHPUnit Unit and Kernel for the testsuite or module.
   *
   * @param string $testsuite
   *   (optional) The testsuite names, separated by commas.
   *
   * @param bool $xml
   *   (optional) Add coverage xml report (--log-junit).
   *
   * @param bool $html
   *   (optional) Add coverage html report (--testdox-html).
   *
   * @param string $module
   *   (optional) The module name.
   */
  public function testSuite($testsuite = 'unit,kernel', $xml = true, $html = true, $module = null) {
    $reportDir = $this->reportDir . '/' . str_replace(',', '_', str_replace('custom', '', $testsuite));
    $this->taskFilesystemStack()->mkdir($reportDir)->run();

    $test = $this->phpUnit($module, $testsuite);
    if ($xml) {
      $test->xml($reportDir . '/phpunit.xml');
    }
    if ($html) {
      $test->option('testdox-html', $reportDir . '/phpunit.html');
    }
    $test->run();
  }

  /**
   * Run PHPUnit code coverage for the testsuite or module.
   *
   * @param string $testsuite
   *   (optional) The testsuite names, separated by commas.
   *
   * @param bool $xml
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
  public function testCoverage($testsuite = 'unit,kernel', $xml = true, $html = true, $text = true, $module = null) {
    $test = $this->phpUnit($module, $testsuite);
    if ($xml) {
      $this->taskFilesystemStack()->mkdir($this->reportDir . '/coverage-xml')->run();
      $test->option('coverage-xml', $this->reportDir . '/coverage-xml');
    }
    if ($html) {
      $this->taskFilesystemStack()->mkdir($this->reportDir . '/coverage-html')->run();
      $test->option('coverage-html', $this->reportDir . '/coverage-html');
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
   * If no configuration is found, it will fall back to Drupal core
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
  public function phpUnit($module = null, $testsuite = null) {

    $this->taskFilesystemStack()->mkdir($this->reportDir)->run();

    $task = $this->taskPhpUnit($this->docRoot . '/vendor/bin/phpunit')
      ->configFile($this->webRoot . '/core');

    if ($this->verbose) {
      $task->arg('--verbose');
    }

    if ($module) {
      $task->group($module);
    }

    if ($testsuite) {
      $task->option('testsuite', $testsuite);
    }
  
    return $task;
  }

  /**
   * Perform a build for the project.
   *
   * Depending the type of project, composer will install the codebase from a 
   * composer.json, or a Drupal project template will be created, or nothing
   * will be installed and we use an included Drupal.
   */
  public function performBuild($dir = null, $forceInstall = false) {
    $this->say("Perform build for type: $this->ciType");

    if (!$dir) {
      $dir = $this->docRoot;
    }

    switch($this->ciType) {
      case "project":
        $task = $this->taskComposerValidate()
          ->workingDir($dir)
          ->noCheckAll()
          ->noCheckPublish();
        if ($this->verbose) {
          $task->arg('--verbose');
        }
        if ($this->noAnsi) {
          $task->noAnsi();
        }
        $task->run();
        if (!file_exists($this->webRoot . '/index.php')) {
          $this->io()->error("Missing Drupal, did you rn composer install?");
        }
        if ($forceInstall || $this->installDrupal) {
          $this->installDrupal();
        }
        break;
      case "custom":
        // Check if already a Drupal project ready.
        if (!file_exists($this->docRoot . '/load.environment.php')) {
          $this->downloadDrupalProject();
        }
        else {
          $this->say("[SKIP] Drupal project already downloaded.");
        }
        if (!file_exists($this->webRoot . '/index.php')) {
          $this->composerInstall();
        }
        else {
          $this->say("[SKIP] Drupal already downloaded.");
        }
      break;
      case "module":
      case "theme":
      $this->say("[SKIP] No needed build.");
        break;
      default:
        $this->io()->error("Invalid ci type: $this->ciType");
    }
  }

  /**
   * Symlink our module/theme in the Drupal.
   */
  public function symlinkFolders() {
    $this->say("Symlink folders for type: $this->ciType");

    // Handle CI values.
    switch($this->ciType) {
      case "project":
      case "custom":
        // Root contain a web/ folder, we symlink each folders.
        $targetFolder = $this->webRoot . '/modules/custom';
        $folder = $this->ciProjectDir . '/web/modules/custom';
        if (file_exists($folder)) {
          $this->linkDrupal($folder, $targetFolder, $targetFolder);
        }
        $targetFolder = $this->webRoot . '/themes/custom';
        $folder = $this->ciProjectDir . '/web/themes/custom';
        if (file_exists($folder)) {
          $this->linkDrupal($folder, $targetFolder, $targetFolder);
        }
        break;
      case "module":
      case "theme":
        // Root contain the theme / module, we symlink with project name.
        $targetFolder = $this->webRoot . '/' . $this->ciType . 's/custom';
        $target = $targetFolder . '/' . $this->ciProjectName;
        $this->linkDrupal($this->ciProjectDir, $targetFolder, $target);
        break;
    }
  }

  private function linkDrupal($folder, $targetFolder, $target) {
    if (file_exists($folder) && !file_exists($target)) {
      $this->say("Symlink $folder to $target");
      // Symlink our folder in the Drupal.
      $this->taskFilesystemStack()
        ->symlink($folder, $target)
        ->run();
    }
    else {
      $this->say("[SKIP] Folder already exist: $target");
    }
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  public function drush($cmd = null) {
    // Need some testing.
    // $this->ensureDrush();
    // Drush needs an absolute path to the docroot.
    $cmd = $this->taskExec($this->docRoot . '/vendor/bin/drush')
      ->option('root', $this->webRoot, '=');

    if ($this->verbose) {
      $cmd->arg('--verbose');
    }

    if ($cmd) {
      $task = $this->drush()
        ->arg($cmd)
        ->run();
    }
    else {
      return $cmd;
    }
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  protected function ensureDrush($dir = null) {
    // if (!file_exists($this->docRoot . '/vendor/bin/drush')) {
    if (!file_exists('/usr/local/bin/drush')) {
      if (!$dir) {
        $dir = $this->docRoot;
      }
      $this->taskComposerRequire()
        ->workingDir($dir)
        ->dependency('drush/drush', '^9')
        ->run();
      }
  }

}
