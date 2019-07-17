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
   *   The docroot folder of Drupal. This can be overridden by specifying a
   *   $DOC_ROOT environment variable.
   */
  protected $docRoot = '/var/www/html';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder of Drupal. This can be overridden by specifying a
   *   $WEB_ROOT environment variable.
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
    if (empty($this->ciProjectDir)) {
      $this->ciProjectDir = getcwd();
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
   * 
   * @param string|null $dir
   *   (optional) Working dir for this task.
   */
  public function updateDependencies($dir = null) {
    if (!$dir) {
      $dir = $this->docRoot;
    }

    // The git checkout includes a composer.lock, and running Composer update
    // on it fails for the first time.
    $this->taskFilesystemStack()->remove('composer.lock')->run();
    $task = $this->taskComposerUpdate()
      ->workingDir($dir)
      ->optimizeAutoloader()
      ->noInteraction()
      ->ignorePlatformRequirements()
      ->option('no-suggest');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
    }
    if ($this->noAnsi) {
      $task->noAnsi();
    }
    $task->run();
  }

  /**
   * Download Drupal 8 project with Composer.
   *
   * @param string|null $destination
   *   (optional) Where is copied the downloaded Drupal.
   */
  public function downloadDrupalProject($destination = null) {

    $tempnam = tempnam(sys_get_temp_dir(), 'drupal.');
    $archive = $tempnam . '.zip';

    if (!$destination) {
      $destination = $this->ciProjectDir;
    }
    $tmp_destination = 'tmp_drupal';

    $client =  new Client();
    $remote = 'https://github.com/drupal-composer/drupal-project/archive/8.x.zip';

    // Get and save file
    $this->say('Downloading Drupal 8 project...');
    $client->get($remote, ['save_to' => $archive]);

    if (!file_exists($archive)) {
      $this->io()->warning('Failed to download Drupal project!');
      exit();
    }

    if (file_exists($tmp_destination)) {
      $this->taskFilesystemStack()
        ->remove($tmp_destination)
        ->run();
    }

    $this->taskExtract($archive)
      ->to($tmp_destination)
      ->run();

    // Remove unused files.
    $files = [
      $tmp_destination . '/README.md',
      $tmp_destination . '/LICENSE',
      $tmp_destination . '/.gitignore',
      $tmp_destination . '/.travis.yml',
      $tmp_destination . '/phpunit.xml.dist',
    ];
    $this->taskFilesystemStack()
      ->remove($files)
      ->run();

    $this->mirror($tmp_destination, $destination);
    $this->taskFilesystemStack()
      ->remove($tmp_destination)
      ->run();

    if (!file_exists($destination . '/web/index.php')) {
      $this->composerInstall($destination);
    }
    else {
      $this->say("Drupal already installed!");
      $this->updateDependencies($destination);
    }
  }

  /**
   * Install Vanilla Drupal 8 project with Composer.
   *
   * @param string|null $destination
   *   (optional) Where is copied the downloaded Drupal.
   */
  public function createDrupalProject($destination = null) {
    if (!$destination) {
      $destination = $this->docRoot;
    }
    $tmp_destination = 'tmp_drupal';

    if (file_exists($tmp_destination)) {
      $this->taskFilesystemStack()
        ->remove($tmp_destination)
        ->run();
    }

    $task = $this->taskComposerCreateProject()
      ->source('drupal-composer/drupal-project:8.x-dev')
      ->target($tmp_destination)
      ->preferDist()
      ->noInteraction()
      ->ignorePlatformRequirements();
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
    }
    if ($this->noAnsi) {
      $task->noAnsi();
    }
    $task->run();

    // Copy to the destination.
    $this->mirror($tmp_destination, $destination);
    
  }

  /**
   * Download Drupal from a composer.json file.
   *
   * @param string|null $dir
   *   (optional) Working dir for this task.
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
      ->option('no-suggest');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
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
   * Check if Drush is here.
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
   *
   * @param string|null $dir
   *   (optional) Working dir for this task.
   *
   * @param bool $forceInstall
   *   (optional) Flag to force the drupal setup.
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
        else {
          $task->arg('--quiet');
        }
        if ($this->noAnsi) {
          $task->noAnsi();
        }
        $task->run();

        $this->composerInstall();

        if (!file_exists($this->webRoot . '/index.php')) {
          $this->io()->error("Missing Drupal, did composer install failed?");
        }
        if ($forceInstall || $this->installDrupal) {
          $this->installDrupal();
        }
        break;
      case "custom":
        $this->downloadDrupalProject();
      break;
      case "module":
      case "theme":
        $this->say("[SKIP] No needed build, you can ignore next Gitlab CI warnings on cache and artifacts.");
        break;
      default:
        $this->io()->error("Invalid ci type: $this->ciType");
    }
  }

  /**
   * Symlink our module/theme in the Drupal or the project.
   */
  public function prepareFolders() {
    $this->say("Prepare folders for type: $this->ciType");

    // Handle CI values.
    switch($this->ciType) {
      case "custom":
        // Root is the Drupal with a web/ folder.
        $targetFolder = $this->docRoot;
        $folder = $this->ciProjectDir;
        if (!file_exists($this->webRoot . '/index.php')) {
          $this->mirror($folder, $this->docRoot);
        }
        else {
          $this->say("[SKIP] Drupal exist in: $this->webRoot/index.php");
        }
        break;
      case "project":
        // Root contain a web/ folder, we symlink each folders.
        $targetFolder = $this->webRoot . '/modules/custom';
        $folder = $this->ciProjectDir . '/web/modules/custom';
        $this->symlink($folder, $targetFolder);
        $targetFolder = $this->webRoot . '/themes/custom';
        $folder = $this->ciProjectDir . '/web/themes/custom';
        $this->symlink($folder, $targetFolder);
        break;
      case "module":
      case "theme":
        // Root contain the theme / module, we symlink with project name.
        $folder = $this->ciProjectDir;
        $target = $this->webRoot . '/' . $this->ciType . 's/custom';
        $this->symlink($folder, $target);
        break;
    }
  }

  /**
   * Helper to symlink.
   *
   * @param string $src
   *   Folder source.
   *
   * @param string $target
   *   Symlink target.
   */
  private function symlink($src, $target) {
    if (file_exists($target)) {
      $this->io()->error("Existing target: $target");
    }
    if (file_exists($src) && !file_exists($target)) {

      $this->say("Symlink $src to $target");
      // Symlink our folder in the target.
      $this->taskFilesystemStack()
        ->symlink($src, $target)
        ->run();
    }
    else {
      $this->say("[SKIP] Folder already exist: $target");
    }
  }

  /**
   * Helper to mirror files and folders.
   *
   * @param string $src
   *   Folder source.
   *
   * @param string $target
   *   Folder target.
   */
  private function mirror($src, $target) {
    if (!file_exists($src)) {
      $this->io()->error("Missing src folder: $src");
    }
    if (!file_exists($target)) {
      $this->io()->error("Missing target folder: $target");
    }

    $this->say("Mirror $src to $target");
    // Mirror our folder in the target.
    $this->taskFilesystemStack()
      ->mirror($src, $target)
      ->run();
  }

  /**
   * Return drush with default arguments.
   *
   * @param string $cmd
   *   (Optional) Folder source.
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
   * @param string|null $dir
   *   (optional) Working dir for this task.
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
