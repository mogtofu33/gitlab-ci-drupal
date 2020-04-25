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

use Symfony\Component\Process\Process;

/**
 * Robofile with tasks for CI.
 */
class RoboFile extends \Robo\Tasks {

  protected $verbose = false;

  /**
   * Database connection information.
   *
   * @var string
   *   The database URL. This can be overridden by specifying a $DB_URL or a
   *   $SIMPLETEST_DB environment variable.
   *   Default is to the ci variables used with mariadb service.
   */
  protected $dbUrl = 'mysql://drupal:drupal@mariadb/drupal';

  /**
   * Web server docroot folder.
   *
   * @var string
   *   The docroot folder of Drupal. This can be overridden by specifying a
   *   $DOC_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $docRoot = '/var/www/html';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder of Drupal. This can be overridden by specifying a
   *   $WEB_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $webRoot = '/var/www/html/web';

  /**
   * CI context type.
   *
   * @var string
   *   The type name, as project, module or theme.
   */
  protected $ciType = 'module';

  /**
   * CI_PROJECT_DIR context.
   *
   * @var string
   *   The CI dir, look at env values for This can be overridden by specifying
   *   a $CI_PROJECT_DIR environment variable.
   *   Default is to Gitlab-ci value.
   */
  protected $ciProjectDir = "/builds";

  /**
   * CI_PROJECT_NAME context.
   *
   * @var string
   *   The CI project name, look at env values for This can be
   *   overridden by specifying a $CI_PROJECT_NAME environment variable.
   */
  protected $ciProjectName = "my_project";

  /**
   * Configuration files for CI context.
   *
   * @var array
   *   The CI files configuration for jobs from .gitlab-ci folder.
   *   Indexed by destination as 'core' (drupal_root/core/) or 'ci'
   *   (.gitlab-ci/).
   */
  protected $ciFiles = [
    'core' => [
      '.eslintignore',
      '.stylelintignore',
      '.env',
      'phpunit.xml',
    ],
    'ci' => [
      '.phpmd.xml',
      '.phpqa.yml',
      'pa11y-ci.json',
      'phpstan.neon',
    ],
  ];

  /**
   * NIGHTWATCH_TESTS context.
   *
   * @var string
   *   The Nightwatch tests to run, look at env values for This can be
   *   overridden by specifying a $NIGHTWATCH_TESTS environment variable.
   */
  protected $nightwatchTests = "--skiptags core";

  /**
   * CI_DRUPAL_VERSION context.
   *
   * @var string
   *   The drupal version used, look at env values for This can be
   *   overridden by specifying a $CI_DRUPAL_VERSION environment variable.
   */
  protected $ciDrupalVersion = "8.8";

  /**
   * CI_DRUPAL_SETTINGS context.
   *
   * @var string
   *   The drupal settings file, look at env values for This can be
   *   overridden by specifying a $CI_DRUPAL_SETTINGS environment variable.
   */
  protected $ciDrupalSettings = "https://gitlab.com/mog33/gitlab-ci-drupal/snippets/1892524/raw";

  /**
   * CI_REF context.
   *
   * @var string
   *   The address of remote ci config files, This can be overridden by
   *   specifying a $CI_REF environment variable.
   */
  protected $ciRef = "";

  /**
   * PHPUNIT_TESTS context.
   *
   * @var string
   *   The type of PHPunit tests, This can be overridden by
   *   specifying a $PHPUNIT_TESTS environment variable.
   */
  protected $phpunitTests = "custom";

  /**
   * RoboFile constructor.
   */
  public function __construct() {
    // Treat this command like bash -e and exit as soon as there's a failure.
    $this->stopOnFail();

    if (getenv('VERBOSE')) {
      $this->verbose = getenv('VERBOSE');
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
    if (getenv('CI_DRUPAL_VERSION')) {
      $this->ciDrupalVersion = getenv('CI_DRUPAL_VERSION');
    }
    if (getenv('CI_DRUPAL_SETTINGS')) {
      $this->ciDrupalSettings = getenv('CI_DRUPAL_SETTINGS');
    }
    if (getenv('CI_REF')) {
      $this->ciRef = getenv('CI_REF');
    }

    // Pull a DB_URL from the environment, if it exists.
    if (filter_var(getenv('DB_URL'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('DB_URL');
    }
    // Pull a SIMPLETEST_DB from the environment, if it exists.
    if (filter_var(getenv('SIMPLETEST_DB'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('SIMPLETEST_DB');
    }

    // Pull a DOC_ROOT from the environment, if it exists.
    if (getenv('DOC_ROOT')) {
      $this->docRoot = getenv('DOC_ROOT');
    }
    // Pull a WEB_ROOT from the environment, if it exists.
    if (getenv('WEB_ROOT')) {
      $this->webRoot = getenv('WEB_ROOT');
    }

    // Pull a NIGHTWATCH_TESTS from the environment, if it exists.
    if (getenv('NIGHTWATCH_TESTS')) {
      $this->nightwatchTests = getenv('NIGHTWATCH_TESTS');
    }

    // Pull a PHPUNIT_TESTS from the environment, if it exists.
    if (getenv('PHPUNIT_TESTS')) {
      $this->phpunitTests = getenv('PHPUNIT_TESTS');
    }

  }

  /**
   * Check for any extra build.php file for the project.
   */
  public function ciBuild() {
    if (file_exists($this->ciProjectDir . '/.gitlab-ci/build.php')) {
      $this->__log('Build extra script detected.');
      include_once $this->ciProjectDir . '/.gitlab-ci/build.php';
      $this->__log('Build extra script executed.');
    }
  }

  /**
   * Get local or remote config files for the CI project.
   */
  public function ciGetConfigFiles() {
    $this->__log("Prepare config files for CI");

    $src_dir = $this->ciProjectDir . '/.gitlab-ci/';
    $drupal_dir = $this->webRoot . '/core/';

    // Manage files for drupal_root/core folder.
    foreach ($this->ciFiles['core'] as $filename) {
      // Use local file if exist.
      if (file_exists($src_dir . $filename)) {
        $this->taskFilesystemStack()
          ->copy($src_dir . $filename, $drupal_dir . $filename, true)
          ->run();
      }
      else {
        $this->__notice("Download remote file: $this->ciRef" . "$filename");
        $remote_file = file_get_contents($this->ciRef . $filename);
        if ($remote_file) {
          file_put_contents($drupal_dir . $filename, $remote_file);
        }
        else {
          $this->io()->warning("Failed to get remote file: $this->ciRef" . "$filename");
        }
      }
    }

    // Create directory if do not exist.
    $this->_mkdir($src_dir);

    // Manage ci configuration files for .gitlab-ci folder.
    foreach ($this->ciFiles['ci'] as $filename) {
      // Use local file if exist.
      if (!file_exists($src_dir . $filename)) {
        $this->__notice("Download remote file: $this->ciRef" . "$filename");
        $remote_file = file_get_contents($this->ciRef . $filename);
        file_put_contents($src_dir . $filename, $remote_file);
      }
    }
  }

  /**
   * Symlink our module/theme in the Drupal or the project.
   */
  public function ciPrepare() {
    $this->__log("Prepare folders for type: $this->ciType");

    // Handle CI Type value.
    switch($this->ciType) {
      case "demo":
        // Override phpunit.xml file if exist.
        if (file_exists($this->ciProjectDir . '/.gitlab-ci/phpunit.xml.' . $this->phpunitTests)) {
          $this->__notice('Override phpunit.xml file with: phpunit.xml.' . $this->phpunitTests);
          if (file_exists($this->ciProjectDir . '/.gitlab-ci/phpunit.xml')) {
            unlink($this->ciProjectDir . '/.gitlab-ci/phpunit.xml');
          }
          copy($this->ciProjectDir . '/.gitlab-ci/phpunit.xml.' . $this->phpunitTests, $this->ciProjectDir . '/.gitlab-ci/phpunit.xml');
        }
        else {
          $this->__log('No override phpunit.xml file found as: phpunit.xml.' . $this->phpunitTests);
        }
      case "project":
        // Root is the Drupal with a web/ folder.
        $targetFolder = $this->docRoot;
        $folder = $this->ciProjectDir;
        if (!file_exists($this->webRoot . '/index.php')) {
          $this->__mirror($folder, $targetFolder);
        }
        else {
          $this->__log("Drupal exist in: $this->webRoot/index.php");
        }

        // Root contain a web/ folder, we mirror each folders.
        $targetFolder = $this->webRoot . '/modules/custom';
        $folder = $this->ciProjectDir . '/web/modules/custom';
        $this->__mirror($folder, $targetFolder, true);
        $targetFolder = $this->webRoot . '/themes/custom';
        $folder = $this->ciProjectDir . '/web/themes/custom';
        $this->__mirror($folder, $targetFolder, true);
        break;
      case "module":
      case "theme":
      case "profile":
        // Root contain the theme / module, we symlink with project name.
        $folder = $this->ciProjectDir;
        $target = $this->webRoot . '/' . $this->ciType . 's/custom/' . $this->ciProjectName;
        $this->__symlink($folder, $target);
        break;
    }

    $this->ciGetConfigFiles();
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
      ->noAnsi()
      ->ignorePlatformRequirements()
      ->option('no-suggest');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
    }
    $task->run();
  }

  /**
   * Helper for preparing a composer require task.
   *
   * @param string|null $dir
   *   (optional) WorkingDir for composer.
   *
   * @return \Robo\Task\Composer\RequireDependency
   */
  public function composerRequire($dir = null) {
    if (!$dir) {
      $dir = $this->docRoot;
    }

    $task = $this->taskComposerRequire()
      ->noInteraction()
      ->noAnsi()
      ->workingDir($dir);

    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
    }
    return $task;
  }

  /**
   * Updates Composer dependencies.
   *
   * @param string|null $dir
   *   (optional) Working dir for this task.
   */
  public function composerUpdate($dir = null) {
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
      ->noAnsi()
      ->ignorePlatformRequirements()
      ->option('no-suggest');
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
    }
    $task->run();
  }

  /**
   * Check Drupal.
   *
   * @return string
   *   Drupal bootstrap result.
   */
  public function drupalCheck() {
    return $this->__drush()
      ->args('status')
      ->option('fields', 'bootstrap', '=')
      ->run();
  }

  /**
   * Dump Drupal DB with Drush.
   *
   * @param string $profile
   *   The profile to install.
   */
  public function drupalDump($profile) {
    if (!file_exists($this->ciProjectDir . '/dump')) {
      $this->_mkdir($this->ciProjectDir . '/dump');
    }
    $this->__drush()
      ->args('sql:dump')
      ->option('result-file', $this->ciProjectDir . '/dump/dump-' . $this->ciDrupalVersion . '_' . $profile . '.sql', '=')
      ->option('gzip')
      ->run();
  }

  /**
   * Setup Drupal or import a db dump if available.
   *
   * @param string $profile
   *   (optional) The profile to install, default to minimal.
   */
  public function drupalInstall($profile = 'minimal') {
    // Ensure permissions.
    $dir = $this->webRoot . '/sites/default/files';
    $this->taskFilesystemStack()
      ->mkdir($dir)
      ->chown($dir, 'www-data', true)
      ->chgrp($dir, 'www-data', true)
      ->chmod($dir, 0777, 0000, true)
      ->run();

    $this->__notice("Installing Drupal with profile $profile...");

    $filename = $this->ciProjectDir . '/dump/dump-' . $this->ciDrupalVersion . '_' . $profile . '.sql';

    if (file_exists($filename . '.gz')) {
      $this->__log("Extract dump $filename.gz");
      $this->_exec('zcat ' . $filename . '.gz > ' . $filename . ';');
    }

    if (file_exists($filename)) {
      $this->__log("Import dump $filename");
      $this->_exec('mysql -hmariadb -uroot drupal < ' . $filename . ';');

      // When install from dump we need to be sure settings.php is correct.
      $settings = file_get_contents($this->ciDrupalSettings);
      if (!file_exists($this->webRoot . '/sites/default/settings.local.php')) {
        file_put_contents($this->webRoot . '/sites/default/settings.local.php', $settings);
      }

      $this->taskFilesystemStack()
        ->remove($this->webRoot . '/sites/default/settings.php')
        ->copy($this->webRoot . '/sites/default/default.settings.php', $this->webRoot . '/sites/default/settings.php', true)
        ->run();
      $this->taskFilesystemStack()
        ->appendToFile($this->webRoot . '/sites/default/settings.php', 'include $app_root . "/" . $site_path . "/settings.local.php";')
        ->run();
    }
    else {
      $this->__log("No dump found $filename, installing Drupal with Drush.");
      $this->drupalSetup($profile);
      $this->drupalDump($profile);
    }

    $this->drupalCheck();
  }

  /**
   * Execute a patch on Drupal.
   *
   * @param string $patch
   *   Local patch file or remote url.
   *
   * @param bool $local
   *   (optional) Flag for a local patch, default is false, means remote.
   */
  public function drupalPatch($patch, $local = FALSE) {
    if (!$local) {
      $patch = file_get_contents($patch);
      file_put_contents($this->webRoot . '/remote_patch.patch', $patch);
      $patch = $this->webRoot . '/remote_patch.patch';
    }
    $this->__log("Apply patch $patch");
    $this->_exec("patch -d $this->webRoot -N -p1 < $patch || true");
  }

  /**
   * Install Drupal from profile or config with config_installer.
   *
   * @param string $profile
   *   (Optional) The profile to install, default to minimal.
   */
  public function drupalSetup($profile = 'minimal') {
    $this->__log("Setup Drupal with $profile...");

    if ($profile == 'config_installer') {
      $task = $this->__drush()
        ->args('site:install', 'config_installer')
        ->arg('config_installer_sync_configure_form.sync_directory=' . $this->docRoot . '/config/sync')
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=');
    }
    else {
      $task = $this->__drush()
        ->args('site:install', $profile)
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=');
    }

    // Sending email will fail, so we need to allow this to always pass.
    $this->stopOnFail(false);
    $task->run();
    $this->stopOnFail();
  }

  /**
   * Print Nightwatch, Chromedriver and Chrome versions.
   */
  public function nightwatchCheck() {
    $bins = [
      $this->webRoot . '/core/node_modules/.bin/nightwatch',
      $this->webRoot . '/core/node_modules/.bin/chromedriver',
      '/usr/bin/google-chrome',
    ];
    foreach ($bins as $bin) {
      if (file_exists($bin)) {
        $this->_exec($bin . ' --version');
      }
      else {
        $this->io()->warning("Missing bin: $bin");
      }
    }
  }

  /**
   * Runs Nightwatch.js tests from a tests folder.
   *
   * @param string|null $reportDir
   *   (Optional) Report dir.
   */
  public function nightwatchRun($reportDir = null) {
    # Patch to allow install profile for Drupal <8.9, see https://drupal.org/node/3017176
    # @TODO: remove when Drupal 8.7 or 8.8 is deprecated.
    if ($this->ciDrupalVersion == "8.7") {
      $this->drupalPatch("https://www.drupal.org/files/issues/2019-09-06/3017176-12.patch");
    }
    if ($this->ciDrupalVersion == "8.8") {
      $this->drupalPatch("https://www.drupal.org/files/issues/2019-11-11/3017176-16.patch");
    }

    if (!file_exists($reportDir)) {
      $this->_mkdir($reportDir);
    }

    $this->nightwatchCheck();

    $task = $this->yarnCmd(['test:nightwatch', $this->nightwatchTests])
      ->option("output_folder", $reportDir, " ")
      ->option("detailed_output", "false", " ")
      ->run();

    if ($task->wasSuccessful()) {
      // Install html reporter if not present.
      if (!file_exists($this->webRoot . '/core/node_modules/.bin/nightwatch-html-reporter')) {
        $this->yarnCmd(['add', 'nightwatch-html-reporter'])
          ->run();
      }
      $this->_exec("$this->webRoot . '/core/node_modules/.bin/nightwatch-html-reporter --report-dir $reportDir --output nightwatch.html --theme outlook --browser false");
    }
  }

  /**
   * Return a configured phpunit task.
   *
   * This will check for PHPUnit configuration core/phpunit.xml
   *
   * @param string $testsuite
   *   (optional) The testsuite names, separated by commas.
   *
   * @return \Robo\Task\Testing\PHPUnit
   */
  public function phpUnit($testsuite = null) {

    $task = $this->taskPhpUnit($this->docRoot . '/vendor/bin/phpunit')
      ->configFile($this->webRoot . '/core');

    if ($this->verbose) {
      $task->arg('--verbose');
      $task->arg('--debug');
    }

    if ($testsuite) {
      $task->option('testsuite', $testsuite);
    }

    return $task;
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  private function __drush() {
    if (!file_exists($this->docRoot . '/vendor/bin/drush')) {
      $task = $this->composerRequire()
        ->dependency('drush/drush', '^10')
        ->run();
    }

    // Drush needs an absolute path to the webroot.
    $task = $this->taskExec($this->docRoot . '/vendor/bin/drush')
      ->option('root', $this->webRoot, '=');

    if ($this->verbose) {
      $task->arg('--verbose');
    }

    return $task;
  }

  /**
   * Log a notice message in the CI logs.
   *
   * @param string $message
   *   Message to log.
   */
  private function __log($message) {
    if ($this->verbose) {
      $this->say("[log] $message");
    }
  }

  /**
   * Log a notice message in the CI logs.
   *
   * @param string $message
   *   Message to log.
   */
  private function __notice($message) {
    $this->say("[notice] $message");
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
  private function __symlink($src, $target) {
    if (file_exists($target)) {
      $this->__log("[SKIP] Existing target: $target, is it a problem?");
    }
    elseif (file_exists($src)) {
      $this->__log("Symlink $src to $target");
      // Symlink our folder in the target.
      $this->taskFilesystemStack()
        ->symlink($src, $target)
        ->run();
    }
    else {
      $this->__log("[SKIP] Source do not exist: $src");
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
   *
   * @param bool $remove_if_exist
   *   (Optional) Flag to remove target if exist.
   */
  private function __mirror($src, $target, $remove_if_exist = false) {
    if (!file_exists($src)) {
      $this->__log("Missing src folder: $src");
    }
    else {
      if (file_exists($target) && $remove_if_exist) {
        $this->taskFilesystemStack()
          ->remove($target)
          ->mkdir($target)
          ->run();
      }
      if (!file_exists($target)) {
        $this->__log("Missing target folder: $target");
      }

      // Mirror our folder in the target.
      $this->taskFilesystemStack()
        ->mirror($src, $target)
        ->run();
    }
  }

}
