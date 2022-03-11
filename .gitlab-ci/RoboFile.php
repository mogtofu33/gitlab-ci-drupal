<?php

/**
 * Base tasks for setting up a module to test within a full Drupal environment.
 *
 * This file expects to be called from the root of a Drupal site.
 *
 * @class RoboFile
 *
 * @SuppressWarnings(PHPMD)
 * phpcs:ignoreFile
 */

use Robo\Tasks;

/**
 * Robofile with tasks for CI.
 *
 * @codeCoverageIgnore
 */
class RoboFile extends Tasks {

  /**
   * Verbosity of some parts of this code.
   *
   * @var bool
   *   Enable verbosity for this code.
   */
  protected $verbose = FALSE;

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
  protected $docRoot = '/opt/drupal';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder of Drupal. This can be overridden by specifying a
   *   $WEB_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $webRoot = '/opt/drupal/web';

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
      'settings.local.php',
    ],
  ];

  /**
   * NIGHTWATCH_TESTS context.
   *
   * @var string
   *   The Nightwatch tests to run, look at env values for. This can be
   *   overridden by specifying a $NIGHTWATCH_TESTS environment variable.
   */
  protected $nightwatchTests = "--skiptags core";

  /**
   * CI_DRUPAL_VERSION context.
   *
   * @var string
   *   The drupal version used, look at env values for. This can be
   *   overridden by specifying a $CI_DRUPAL_VERSION environment variable.
   */
  protected $ciDrupalVersion = "9.3";

  /**
   * CI_REMOTE_FILES context.
   *
   * @var string
   *   The address of remote ci config files. This can be overridden by
   *   specifying a $CI_REMOTE_FILES environment variable.
   */
  protected $ciRemoteRef = "";

  /**
   * PHPUNIT_TESTS context.
   *
   * @var string
   *   The type of PHPunit tests. This can be overridden by specifying
   *   a $PHPUNIT_TESTS environment variable.
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
    if (getenv('CI_REMOTE_FILES')) {
      $this->ciRemoteRef = getenv('CI_REMOTE_FILES');
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
   * Check for any extra php file to execute during ci pre/post build step.
   *
   * @param string $name
   *   (optional) The filename to execute from ./.gitlab-ci, default 'build'.
   */
  public function ciBuild($name = 'build') {
    $filename = $this->ciProjectDir . '/.gitlab-ci/' . $name . '.php';
    if (file_exists($filename)) {
      $this->ciLog('Build extra script detected: ' . $filename);
      include_once $filename;
      $this->ciLog('Build extra script executed.');
    }
    else {
      $this->ciLog('No extra script found: ' . $filename);
    }
  }

  /**
   * Get local or remote config files for the CI project.
   */
  public function ciGetConfigFiles() {
    $this->ciLog("Prepare config files for CI");

    $src_dir = $this->ciProjectDir . '/.gitlab-ci/';
    $drupal_dir = $this->webRoot . '/core/';

    // Manage files for drupal_root/core folder.
    foreach ($this->ciFiles['core'] as $filename) {
      // Use local file if exist.
      if (file_exists($src_dir . $filename)) {
        $this->ciNotice("Use local core file: $src_dir" . "$filename");
        $this->taskFilesystemStack()
          ->copy($src_dir . $filename, $drupal_dir . $filename, TRUE)
          ->run();
      }
      else {
        $this->ciNotice("Download remote core file: $this->ciRemoteRef" . "$filename");
        $remote_file = file_get_contents($this->ciRemoteRef . $filename);
        if ($remote_file) {
          file_put_contents($drupal_dir . $filename, $remote_file);
        }
        else {
          $this->io()->warning("Failed to get remote core file: $this->ciRemoteRef" . "$filename");
        }
      }
    }

    // Create directory if do not exist.
    $this->_mkdir($src_dir);

    // Manage ci configuration files for .gitlab-ci folder.
    foreach ($this->ciFiles['ci'] as $filename) {
      // Use remote file if local do not exist.
      if (!file_exists($src_dir . $filename)) {
        $this->ciNotice("Download remote ci file: $this->ciRemoteRef" . "$filename");
        $remote_file = file_get_contents($this->ciRemoteRef . $filename);
        if ($remote_file) {
          file_put_contents($src_dir . $filename, $remote_file);
        }
        else {
          $this->io()->warning("Failed to get remote ci file: $this->ciRemoteRef" . "$filename");
        }
      }
      else {
        $this->ciNotice("Use local ci file: $src_dir" . "$filename");
      }
    }
  }

  /**
   * Mirror our module/theme in the Drupal or the project.
   *
   * @param bool $getConfigFiles
   *   (optional) Get config files in the process, default true.
   */
  public function ciPrepare($getConfigFiles = TRUE) {
    // Override phpunit.xml file if a custom one exist.
    if (file_exists($this->ciProjectDir . '/.gitlab-ci/phpunit.xml.' . $this->phpunitTests)) {
      $this->ciNotice('Override phpunit.xml file with: phpunit.xml.' . $this->phpunitTests);
      if (file_exists($this->ciProjectDir . '/.gitlab-ci/phpunit.xml')) {
        unlink($this->ciProjectDir . '/.gitlab-ci/phpunit.xml');
      }
      $this->taskFilesystemStack()
        ->copy(
          $this->ciProjectDir . '/.gitlab-ci/phpunit.xml.' . $this->phpunitTests,
          $this->ciProjectDir . '/.gitlab-ci/phpunit.xml',
          TRUE
          )
        ->run();
    }
    else {
      $this->ciLog('No override phpunit.xml file found as: phpunit.xml.' . $this->phpunitTests);
    }

    $this->ciLog("Prepare folders for type: $this->ciType");

    // Handle CI Type value.
    switch ($this->ciType) {
      case "project":
        // We have a composer.json file.
        if (file_exists($this->ciProjectDir . '/composer.json')) {
          $this->ciLog("Project include Drupal, let mirror.");
          // Cannot symlink because $this->docRoot is a mounted volume.
          $this->ciMirror(
            $this->ciProjectDir,
            $this->docRoot
          );
        }
        else {
          $this->ciLog("Project seems to have only custom code.");
          // Root contain a web/ folder, we mirror each folders.
          foreach (['modules', 'themes', 'profiles'] as $type) {
            $this->ciMirror(
              $this->ciProjectDir . '/web/' . $type . '/custom',
              $this->webRoot . '/' . $type . '/custom'
            );
          }
        }
        break;

      case "module":
      case "theme":
      case "profile":
        // If we have a custom build, run it now, see issue:
        // https://gitlab.com/mog33/gitlab-ci-drupal/-/issues/32
        $this->ciBuild();
        // Root contain the theme / module, we mirror with project name.
        $this->ciMirror(
          $this->ciProjectDir,
          $this->webRoot . '/' . $this->ciType . 's/custom/' . $this->ciProjectName
        );
        break;
    }

    if ($getConfigFiles) {
      $this->ciGetConfigFiles();
    }
  }

  /**
   * Download Drupal from a composer.json file.
   *
   * @param string|null $dir
   *   (optional) Working dir for this task.
   */
  public function composerInstall($dir = NULL) {
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
   *   Robo composer require task with some specific settings.
   */
  public function composerRequire($dir = NULL) {
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
  public function composerUpdate($dir = NULL) {
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
    return $this->ciDrush()
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
    $this->ciDrush()
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
      ->chown($dir, 'www-data', TRUE)
      ->chgrp($dir, 'www-data', TRUE)
      ->chmod($dir, 0777, 0000, TRUE)
      ->run();

    $this->ciNotice("Installing Drupal with profile $profile, check if dump file exist...");

    $filename = $this->ciProjectDir . '/dump/dump-' . $this->ciDrupalVersion . '_' . $profile . '.sql';

    if (file_exists($filename . '.gz')) {
      $this->ciLog("Extract dump $filename.gz");
      $this->_exec('zcat ' . $filename . '.gz > ' . $filename . ';');
    }

    if (file_exists($filename)) {
      $this->ciLog("Import dump $filename");
      $this->_exec('mysql -hmariadb -uroot drupal < ' . $filename . ';');

      // When install from dump we need to be sure settings.php is correct.
      $settings = file_get_contents($this->ciProjectDir . '/.gitlab-ci/settings.local.php');
      if (!file_exists($this->webRoot . '/sites/default/settings.local.php')) {
        $this->taskFilesystemStack()
          ->copy($this->ciProjectDir . '/.gitlab-ci/settings.local.php', $this->webRoot . '/sites/default/settings.local.php', TRUE)
          ->run();
      }

      $this->taskFilesystemStack()
        ->remove($this->webRoot . '/sites/default/settings.php')
        ->copy($this->webRoot . '/sites/default/default.settings.php', $this->webRoot . '/sites/default/settings.php', TRUE)
        ->run();
      $this->taskFilesystemStack()
        ->appendToFile($this->webRoot . '/sites/default/settings.php', 'include $app_root . "/" . $site_path . "/settings.local.php";')
        ->run();
    }
    else {
      $this->ciLog("No dump found $filename, installing Drupal with Drush.");
      $this->drupalSetup($profile);
    }

    $this->drupalCheck();
  }

  /**
   * Install Drupal from profile or config with config_installer.
   *
   * @param string $profile
   *   (Optional) The profile to install, default to minimal.
   */
  public function drupalSetup($profile = 'minimal') {
    $this->ciLog("Setup Drupal with $profile...");

    // @TODO: use drush --existing-config instead.
    if ($profile == 'config_installer') {
      $task = $this->ciDrush()
        ->args('site:install', 'config_installer')
        ->arg('config_installer_sync_configure_form.sync_directory=' . $this->docRoot . '/config/sync')
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=');
    }
    else {
      $task = $this->ciDrush()
        ->args('site:install', $profile)
        ->option('yes')
        ->option('db-url', $this->dbUrl, '=');
    }

    // Sending email will fail, so we need to allow this to always pass.
    $this->stopOnFail(FALSE);
    $task->run();
    $this->stopOnFail();
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  private function ciDrush() {
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
  private function ciLog($message) {
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
  private function ciNotice($message) {
    $this->say("[notice] $message");
  }

  /**
   * Helper to mirror files and folders.
   *
   * @param string $src
   *   Folder source.
   * @param string $target
   *   Folder target.
   */
  private function ciMirror($src, $target) {
    if (!file_exists($src)) {
      $this->ciNotice("Missing src folder: $src");
    }
    else {
      if (!file_exists($target)) {
        $this->ciNotice("Missing target folder: $target");
      }

      // Mirror our folder in the target.
      $this->taskFilesystemStack()
        ->mirror($src, $target)
        ->run();
    }
  }

}
