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
  protected $webRoot = '/var/www/html/web';

  /**
   * Drupal setup profile.
   *
   * @var string
   *   The profile name. This can be overridden by specifying a
   *   $DRUPAL_INSTALL_PROFILE environment variable.
   */
  protected $setupProfile = 'minimal';

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
   *   The type name, as project, module or theme.
   */
  protected $ciType = 'module';

  /**
   * CI_PROJECT_DIR context.
   *
   * @var string
   *   The CI dir, look at env values for This can be  overridden by specifying
   *   a $CI_PROJECT_DIR environment variable.
   */
  protected $ciProjectDir = "";

  /**
   * CI_PROJECT_NAME context.
   *
   * @var string
   *   The CI project name, look at env values for This can be
   *   overridden by specifying a $CI_PROJECT_NAME environment variable.
   */
  protected $ciProjectName = "my_project";

  /**
   * NIGHTWATCH_TESTS context.
   *
   * @var string
   *   The Nightwatch tests to run, look at env values for This can be
   *   overridden by specifying a $NIGHTWATCH_TESTS environment variable.
   */
  protected $nightwatchTests = "--skiptags core";

  /**
   * BROWSERTEST_OUTPUT_DIRECTORY context.
   *
   * @var string
   *   The Drupal browser test output look at env values for This can be
   *   overridden by specifying a $BROWSERTEST_OUTPUT_DIRECTORY environment variable.
   */
  protected $browsertestOutput = "/var/www/html/web/sites/simpletest";

  /**
   * APACHE_RUN_USER context.
   *
   * @var string
   *   The CI apache run user, look at env values for This can be
   *   overridden by specifying a $APACHE_RUN_USER environment variable.
   */
  protected $apacheUser = "www-data";

  /**
   * APACHE_RUN_GROUP context.
   *
   * @var string
   *   The CI apache run group, look at env values for This can be
   *   overridden by specifying a $APACHE_RUN_GROUP environment variable.
   */
  protected $apacheGroup = "www-data";

  /**
   * COMPOSER_HOME context.
   *
   * @var string
   *   The composer home dir, look at env values for This can be
   *   overridden by specifying a $COMPOSER_HOME environment variable.
   */
  protected $composerHome = "/var/www/.composer";

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

    // Pull a DB_DUMP from the environment, if it exists.
    if (getenv('DB_DUMP')) {
      $this->dbDump = getenv('DB_DUMP');
    }
    // Pull a DRUPAL_INSTALL_PROFILE from the environment, if it exists.
    if (filter_var(getenv('DRUPAL_INSTALL_PROFILE'))) {
      $this->setupProfile = getenv('DRUPAL_INSTALL_PROFILE');
    }

    // Pull a REPORT_DIR from the environment, if it exists.
    if (getenv('REPORT_DIR')) {
      $this->reportDir = getenv('REPORT_DIR');
    }

    // Pull a BROWSERTEST_OUTPUT_DIRECTORY from the environment, if it exists.
    if (getenv('BROWSERTEST_OUTPUT_DIRECTORY')) {
      $this->browsertestOutput = getenv('BROWSERTEST_OUTPUT_DIRECTORY');
    }

    // Pull a NIGHTWATCH_TESTS from the environment, if it exists.
    if (getenv('NIGHTWATCH_TESTS')) {
      $this->nightwatchTests = getenv('NIGHTWATCH_TESTS');
    }

    // Pull a APACHE_RUN_USER from the environment, if it exists.
    if (getenv('APACHE_RUN_USER')) {
      $this->apacheUser = getenv('APACHE_RUN_USER');
    }
    // Pull a APACHE_RUN_GROUP from the environment, if it exists.
    if (getenv('APACHE_RUN_GROUP')) {
      $this->apacheGroup = getenv('APACHE_RUN_GROUP');
    }
    // Pull a COMPOSER_HOME from the environment, if it exists.
    if (getenv('COMPOSER_HOME')) {
      $this->composerHome = getenv('COMPOSER_HOME');
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

    $this->installPrestissimo();

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

    $this->installPrestissimo();

    $task = $this->taskComposerCreateProject()
      ->source('drupal/core-recommended:^' . $this->CI_DRUPAL_VERSION)
      ->target($tmp_destination)
      ->preferDist()
      ->noInteraction()
      ->noAnsi()
      ->ignorePlatformRequirements();
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
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

    $this->installPrestissimo();

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
   * Setup Drupal or import a db dump if available.
   *
   * @param string $profile
   *   (optional) The profile to install, default to minimal or DRUPAL_INSTALL_PROFILE.
   */
  public function installDrupal($profile = null) {
    // Ensure permissions.
    $dir = $this->webRoot . '/sites/default/files';
    $this->taskFilesystemStack()
      ->mkdir($dir)
      ->chown($dir, $this->apacheUser, true)
      ->chgrp($dir, $this->apacheGroup, true)
      ->chmod($dir, 0777, 0000, true)
      ->run();

    if (!$profile) {
      $profile = $this->setupProfile;
    }
    $this->say("Installing Drupal with $profile...");

    $filename = $this->dbDump . '/dump-' . $this->ciDrupalVersion . '_' . $profile . '.sql';

    if (file_exists($filename . '.gz')) {
      $this->say("Extract dump $filename.gz");
      $this->_exec('zcat ' . $filename . '.gz > ' . $filename . ';');
    }

    if (file_exists($filename)) {
      $this->say("Import dump $filename");
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
      $this->say("No dump found $filename, installing Drupal with Drush.");
      $this->setupDrupal($profile);
      $this->dumpDrupal($profile);
    }

    $this->checkDrupal();
  }

  /**
   * Install Drupal from profile or config with config_installer.
   *
   * @param string $profile
   *   The profile to install, default to minimal or env DRUPAL_INSTALL_PROFILE.
   */
  public function setupDrupal($profile) {
    $this->say("Setup Drupal with $profile...");

    if ($profile == 'config_installer') {
      $task = $this->drush()
        ->args('site:install', 'config_installer')
        ->arg('config_installer_sync_configure_form.sync_directory=' . $this->docRoot . '/config/sync')
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=');
    }
    else {
      if (!$profile) {
        $profile = $this->setupProfile;
      }
      $task = $this->drush()
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
   * Check Drupal.
   *
   * @return string
   *   Drupal bootstrap result.
   */
  public function checkDrupal() {
    return $this->drush()
      ->args('status')
      ->option('fields', 'bootstrap', '=')
      ->run();
  }

  /**
   * Dump Drupal DB with Drush.
   *
   * @param string $profile
   *   The profile to install, default to minimal or env DRUPAL_INSTALL_PROFILE..
   */
  public function dumpDrupal($profile) {
    if (!file_exists($this->dbDump)) {
      $this->taskFilesystemStack()
        ->mkdir($this->dbDump)
        ->run();
    }
    $this->drush()
      ->args('sql:dump')
      ->option('result-file', $this->dbDump . '/dump-' . $this->ciDrupalVersion . '_' . $profile . '.sql', '=')
      ->option('gzip')
      ->run();
  }

  /**
   * Run PHPUnit testsuite or module.
   *
   * @param string $testsuite
   *   (optional) The testsuite names, separated by commas.
   *
   * @param string|null $module
   *   (optional) The name of the module.
   */
  public function testSuite($testsuite = 'unit,kernel', $module = null, $reportDir = null) {
    // Prepare report dir.
    if ($reportDir) {
      $reportDir = $reportDir . '/' . str_replace(',', '_', str_replace('custom', '', $testsuite));
    }
    else {
      $reportDir = $this->reportDir;
    }

    if (!is_dir($reportDir)) {
      $this->taskFilesystemStack()
        ->mkdir($reportDir)
        ->run();
    }

    $test = $this->phpUnit($module, $testsuite)
      ->xml($reportDir . '/phpunit.xml')
      ->option('testdox-html', $reportDir . '/phpunit.html')
      ->run();
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
      $this->taskFilesystemStack()
        ->mkdir($this->reportDir . '/coverage-xml')
        ->run();
      $test->option('coverage-xml', $this->reportDir . '/coverage-xml');
      // For Codecov.
      $test->option('coverage-clover', $this->reportDir . '/coverage.xml');
    }
    if ($html) {
      $this->taskFilesystemStack()
        ->mkdir($this->reportDir . '/coverage-html')
        ->run();
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
  private function phpUnit($module = null, $testsuite = null) {

    if (!file_exists($this->docRoot . '/vendor/bin/phpunit')) {
      $this->requireDrupalDev();
    }

    $task = $this->taskPhpUnit($this->docRoot . '/vendor/bin/phpunit')
      ->configFile($this->webRoot . '/core');

    if ($this->verbose) {
      $task->arg('--verbose');
      $task->arg('--debug');
    }

    if ($module && $module != "null") {
      $task->group($module);
    }

    if ($testsuite) {
      $task->option('testsuite', $testsuite);
    }

    return $task;
  }

  /**
   * Install Drupal Core Dev.
   *
   * @return array
   */
  public function requireDrupalDev() {
    $task = $this->composerRequire($this->docRoot)
      ->dev()
      ->dependency("drupal/core-dev", "^$this->ciDrupalVersion")
      ->run();
  }

  /**
   * Runs Behat tests from a tests folder.
   *
   * @param string|null $reportRootDir
   *   (optional) Report root dir for this task.
   */
  public function testBehat($reportRootDir = null) {

    if (!$reportRootDir) {
      $reportRootDir = $this->reportDir;
    }

    $this->taskFilesystemStack()
      ->mkdir($reportRootDir )
      ->mkdir($this->docRoot . '/tests')
      ->mirror($this->ciProjectDir . '/tests', $this->docRoot . '/tests')
      ->run();

    $task = $this->taskBehat()
      ->dir($this->webRoot)
      ->config($this->docRoot . '/tests/behat.yml')
      ->noInteraction()
      ->noColors()
      ->option('format', 'html', '=')
      ->option('out', $reportRootDir, '=');
    if ($this->verbose) {
      $task->verbose('v');
    }
    $task->run();
  }

  /**
   * Install or locate Behat.
   *
   * @return array
   */
  public function installBehat() {

    $install = [
      'behat' => [
        'bex/behat-screenshot' => '^1.2',
        'dmore/behat-chrome-extension' => '^1.3',
        'emuse/behat-html-formatter' => '0.1.*',
      ],
    ];
  
    if ($this->ciDrupalVersion[0] == "8") {
      $install['behat']['drupal/drupal-extension'] = '~4.0';
    }

    $this->installWithComposer($install, 'drupal');

    // Add bin to use taskBehat().
    if (file_exists('/usr/local/bin/behat')) {
      $this->taskFilesystemStack()
        ->remove('/usr/local/bin/behat')
        ->run();
    }

    $this->symlink($this->docRoot . '/vendor/behat/behat/bin/behat', '/usr/local/bin/behat');
  }

  /**
   * Runs Nightwatch.js tests from a tests folder.
   *
   * @param string|null $reportDir
   *   (Optional) Report dir.
   */
  public function testNightwatch($reportDir = null) {

    $this->prepareNightwatch();

    $this->checkNightwatch();

    // Install html reporter if not present.
    if (!file_exists($this->webRoot . '/core/node_modules/.bin/nightwatch-html-reporter')) {
      $this->yarnCmd(['add', 'nightwatch-html-reporter'])
        ->run();
    }

    $task = $this->yarnCmd(['test:nightwatch', $this->nightwatchTests])
      ->option("reporter", './html-reporter.js', " ")
      ->run();

    if ($task->wasSuccessful()) {
      if (!$reportDir) {
        $reportDir = $this->ciProjectDir . '/' . $this->reportDir;
      }
      $this->artifactsNightwatch($reportDir);
    }
  }

  /**
   * Prepare Nightwatch.js tests folders.
   */
  public function prepareNightwatch() {
    $this->say("Prepare reports for Nightwatch");
    $dirs = [
      $this->reportDir . '/nightwatch',
      $this->webRoot . '/core/reports/',
    ];

    $task = $this->taskFilesystemStack();
    foreach ($dirs as $dir) {
      $task->mkdir($dir)
        ->chown($dir, $this->apacheUser, true)
        ->chgrp($dir, $this->apacheGroup, true)
        ->chmod($dir, 0777, 0000, true);
    }
    $task->run();
  }

  /**
   * Prepare Nightwatch.js tests folders.
   *
   * @param string $reportDir
   *   Report dir.
   */
  private function artifactsNightwatch($reportDir) {
    $this->say("Create artifact for Nightwatch");

    $task = $this->taskFilesystemStack()
      ->mkdir($reportDir)
      ->mirror($this->webRoot . '/core/reports/', $reportDir);

    if (file_exists($this->webRoot . '/core/chromedriver.log')) {
      $task->copy($this->webRoot . '/core/chromedriver.log', $reportDir . '/chromedriver.log', true);
    }

    $task->run();
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
  public function patchNightwatch($patch, $local = FALSE) {
    if (!$local) {
      $patch = file_get_contents($patch);
      file_put_contents($this->webRoot . '/remote_patch.patch', $patch);
      $patch = $this->webRoot . '/remote_patch.patch';
    }
    $this->say("Apply patch $patch");
    $this->_exec("patch -d $this->webRoot -N -p1 < $patch || true");
  }

  /**
   * Print Nightwatch, Chromedriver and Chrome versions.
   */
  private function checkNightwatch() {
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
   * Install or locate Drush.
   *
   * @return array
   */
  public function installDrush() {
    $install = [
      'drush' => [
        'drush/drush' => '^10',
      ],
    ];
    $this->installWithComposer($install, 'drupal');

    if (file_exists('/usr/local/bin/drush')) {
      $this->taskFilesystemStack()
        ->remove('/usr/local/bin/drush')
        ->run();
    }
    $this->symlink($this->docRoot . '/vendor/bin/drush', '/usr/local/bin/drush');
  }

  /**
   * Install with composer.
   *
   * @param array $bins_dependencies
   *   Keys are bins to look for, values array of dependencies.
   *
   * @param string|null $target
   *   (optional) Working dir, can be drupal, ie:/var/www/html
   *   or user, ie: /var/www/.composer
   *
   * @param bool $dev
   *   (optional) Install as require-dev. Default true.
   *
   * @return \Robo\Task\Base\Exec
   */
  private function installWithComposer(array $bins_dependencies, $target = 'drupal', $dev = true) {
    $this->installPrestissimo();
    $this->installCoder();

    if ($target == 'drupal') {
      $dir = $this->docRoot;
    }
    else {
      $dir = $this->composerHome;
    }

    // Base task.
    $task = $this->composerRequire($dir)
      ->dev();

    $hasDependency = false;
    foreach ($bins_dependencies as $bin => $dependencies) {
      $bin = $dir . '/vendor/bin/' . $bin;

      if (!file_exists($bin)) {
        foreach ($dependencies as $dependency => $version) {
          $hasDependency = true;
          $task->dependency($dependency, $version);
        }
      }
      elseif ($this->verbose) {
        $this->say("[SKIP] Already installed: $bin");
      }
    }

    if ($hasDependency) {
      $task->run();
    }
    elseif ($this->verbose) {
      $this->say("[SKIP] Composer install, nothing to install!");
    }

  }

  /**
   * Install prestissimo for Composer.
   */
  public function installPrestissimo() {
    // First check if we have prestissimo.
    if (!file_exists($this->composerHome . '/vendor/hirak/prestissimo/composer.json')) {
      $task = $this->composerRequire()
        ->dependency('hirak/prestissimo', '^0.3.8')
        ->run();
    }
    elseif ($this->verbose) {
      $this->say("Prestissimo already installed!");
    }
  }

  /**
   * Install Coder for Composer.
   */
  public function installCoder() {
    $hasDependency = false;
    $task = $this->composerRequire($this->composerHome);

    // First check if we have coder.
    if (!file_exists($this->composerHome . '/vendor/drupal/coder/composer.json')) {
      $hasDependency = true;
      $task->dependency('drupal/coder', '^8.3');
    }
    if (!file_exists($this->composerHome . '/vendor/dealerdirect/phpcodesniffer-composer-installer/composer.json')) {
      $hasDependency = true;
      $task->dependency('dealerdirect/phpcodesniffer-composer-installer', '^0.6');
    }
    if ($hasDependency) {
      $task->run();
    }
    elseif ($this->verbose) {
      $this->say("Coder already installed!");
    }
  }

  /**
   * Helper for preparing a composer require task.
   *
   * @param string|null $dir
   *   (optional) WorkingDir for composer.
   *
   * @return \Robo\Task\Composer\RequireDependency
   */
  private function composerRequire($dir = null) {
    $task = $this->taskComposerRequire()
      ->noInteraction()
      ->noAnsi();
    if ($dir) {
      $task->workingDir($dir);
    }
    if ($this->verbose) {
      $task->arg('--verbose');
    }
    else {
      $task->arg('--quiet');
    }
    return $task;
  }

  /**
   * Install Pa11y with yarn.
   */
  public function installPa11y() {
    $this->yarn('add', 'pa11y-ci');
  }

  /**
   * Runs Pa11y tests.
   */
  public function testPa11y() {
    $task = $this->_exec($this->webRoot . '/core/node_modules/.bin/pa11y-ci --config ' . $this->ciProjectDir . '/.gitlab-ci/pa11y-ci.json');
  }

  /**
   * Run a yarn command.
   *
   * @param string $arg1
   *   First argument for yarn command.
   *
   * @param string|null $arg2
   *   (optional) Second argument for yarn command.
   *
   * @param string|null $dir
   *   (optional) Dir to run the command in.
   */
  public function yarn($arg1, $arg2 = null, $dir = null) {
    $args = [];
    if ($arg2) {
      $args = [$arg1, $arg2];
    }
    else {
      $args = [$arg1];
    }
    if (!$dir) {
      $dir = $this->webRoot . '/core';
    }
    $this->say("yarn " . implode(' ', $args) . " dir: " . $dir);
    $this->yarnCmd($args, $dir)->run();
  }

  /**
   * Run a yarn install from Drupal core.
   *
   * @param string|null $dir
   *   (optional) Dir to run the command in.
   */
  public function yarnInstall($dir = null) {
    if (!$dir) {
      $dir = $this->webRoot . '/core';
    }

    if (!file_exists($dir . '/package.json')) {
      $this->io()->warning("Missing $dir/package.json file.");
    }
    else {
      // Check one of the program to decide if an install is needed.
      if (!file_exists($dir . '/node_modules/.bin/stylelint') || !file_exists($dir . '/node_modules/.bin/eslint')) {
        $this->yarn('install', null, $dir);
      }
      elseif ($this->verbose) {
        $this->say("[SKIP] yarn install not needed.");
      }

      $this->checkChromedriver($dir);
    }
  }

  /**
   * Compare Chrome / Chromedriver and update if needed.
   *
   * @param string|null $dir
   *   (optional) Dir to run the command in.
   */
  private function checkChromedriver($dir = null) {

    $chromeVersion = $chromedriverVersion = NULL;

    // Check current versions.
    $chromeProcess = new Process(['/usr/bin/google-chrome', '--version']);
    $chromeProcess->run();
    $chromedriverProcess = new Process([$this->webRoot . '/core/node_modules/.bin/chromedriver', '--version']);
    $chromedriverProcess->run();

    // Compare major version and upgrade Chromedriver if needed.
    if ($chromeProcess->isSuccessful() && $chromedriverProcess->isSuccessful()) {
      $chromeVersion = explode(" ", $chromeProcess->getOutput());
      $chromeVersion = explode(".", $chromeVersion[2]);
      $chromedriverVersion = explode(" ", $chromedriverProcess->getOutput());
      $chromedriverVersion = explode(".", $chromedriverVersion[1]);
      $chromeVersion = $chromeVersion[0];
      $chromedriverVersion = $chromedriverVersion[0];
      if ($chromeVersion != $chromedriverVersion && (int)$chromeVersion > (int)$chromedriverVersion) {
        $this->say("Try to upgrade Chromedriver to Chrome version $chromeVersion");
        $this->yarn('upgrade', 'chromedriver@' . $chromeVersion, $dir);
      }
    }
    else {
      $this->io()->error("Failed to get Chrome or chromedriver version.");
    }
  }

  /**
   * Return a yarn task.
   *
   * @param string|array $args
   *   (optional) Arguments for yarn command.
   *
   * @param string|null $dir
   *   (optional) Working directory to use.
   *
   * @return \Robo\Task\Base\Exec
   */
  private function yarnCmd($args = null, $dir = null) {
    if (!$dir) {
      $dir = $this->webRoot . '/core';
    }

    $task = $this->taskExec('yarn')
      ->option('cwd', $dir)
      ->arg('--no-progress');

    if ($args) {
      if (is_array($args)) {
        $task->args($args);
      }
      else {
        $task->arg($args);
      }
    }

    if (!$this->verbose) {
      $task->arg('--silent');
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
  public function projectBuild($dir = null, $forceInstall = false) {
    $this->say("Drupal: $this->ciDrupalVersion");
    $this->say("Build for type: $this->ciType");

    if (!$dir) {
      $dir = $this->ciProjectDir;
    }

    switch($this->ciType) {
      case "project":
        $task = $this->taskComposerValidate()
          ->workingDir($dir)
          ->noInteraction()
          ->noAnsi()
          ->noCheckAll()
          ->noCheckPublish();
        if ($this->verbose) {
          $task->arg('--verbose');
        }
        $task->run();

        $this->composerInstall($dir);

        if (!file_exists($dir . '/web/index.php')) {
          $this->io()->error("Missing Drupal, did composer install failed?");
        }
        if ($forceInstall) {
          $this->installDrupal();
        }
        break;
      case "module":
        if ($this->verbose) {
          $this->say("[SKIP] No needed build.");
        }
        break;
      default:
        $this->say("[SKIP] Nothing to build");
    }
  }

  /**
   * Symlink our module/theme in the Drupal or the project.
   */
  public function prepareFolders() {
    $this->say("Prepare folders for type: $this->ciType");

    // Handle CI values.
    switch($this->ciType) {
      case "demo":
      case "project":
        // Root is the Drupal with a web/ folder.
        $targetFolder = $this->docRoot;
        $folder = $this->ciProjectDir;
        if (!file_exists($this->webRoot . '/index.php')) {
          $this->mirror($folder, $targetFolder);
        }
        elseif ($this->verbose) {
          $this->say("[SKIP] Drupal exist in: $this->webRoot/index.php");
        }

        // Root contain a web/ folder, we mirror each folders.
        $targetFolder = $this->webRoot . '/modules/custom';
        $folder = $this->ciProjectDir . '/web/modules/custom';
        $this->mirror($folder, $targetFolder, true);
        $targetFolder = $this->webRoot . '/themes/custom';
        $folder = $this->ciProjectDir . '/web/themes/custom';
        $this->mirror($folder, $targetFolder, true);
        break;
      case "module":
        // Root contain the theme / module, we symlink with project name.
        $folder = $this->ciProjectDir;
        $target = $this->webRoot . '/' . $this->ciType . 's/custom/' . $this->ciProjectName;
        $this->symlink($folder, $target);
        break;
    }
  }

  /**
   * Ensure owner for permissions on tests and reports dir.
   */
  public function ensureTestsFolders() {
    $dirs = [
      $this->webRoot . '/sites',
      $this->webRoot . '/modules',
      $this->webRoot . '/themes',
      $this->webRoot . '/profiles',
      $this->browsertestOutput,
      $this->browsertestOutput . '/browser_output',
      $this->reportDir,
    ];

    foreach ($dirs as $dir) {
      $this->taskFilesystemStack()
        ->mkdir($dir)
        ->chown($dir, $this->apacheUser, true)
        ->chgrp($dir, $this->apacheGroup, true)
        ->chmod($dir, 0777, 0000, true)
        ->run();
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
      $this->say("[SKIP] Existing target: $target, is it a problem?");
    }
    elseif (file_exists($src)) {

      $this->say("Symlink $src to $target");
      // Symlink our folder in the target.
      $this->taskFilesystemStack()
        ->symlink($src, $target)
        ->run();
    }
    elseif ($this->verbose) {
      $this->say("[SKIP] Source do not exist: $src");
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
  private function mirror($src, $target, $remove_if_exist = false) {
    if (!file_exists($src)) {
      $this->say("[NOTICE] Missing src folder: $src");
    }
    else {
      if (file_exists($target) && $remove_if_exist) {
        $this->taskFilesystemStack()
          ->remove($target)
          ->mkdir($target)
          ->run();
      }
      if (!file_exists($target)) {
        $this->say("[NOTICE] Missing target folder: $target");
      }

      // Mirror our folder in the target.
      $this->taskFilesystemStack()
        ->mirror($src, $target)
        ->run();
    }
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  private function drush() {
    $this->installDrush();

    // Drush needs an absolute path to the webroot.
    $task = $this->taskExec($this->docRoot . '/vendor/bin/drush')
      ->option('root', $this->webRoot, '=');

    if ($this->verbose) {
      $task->arg('--verbose');
    }

    return $task;
  }

}
