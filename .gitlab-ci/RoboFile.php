<?php

/**
 * Base tasks for CI commands in https://gitlab.com/mog33/gitlab-ci-drupal.
 *
 * This file expects to be called from the root of a Drupal site based on
 * official Docker Drupal image.
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
   *   The database driver. This can be overridden by specifying a $DB_DRIVER.
   *   Default is to the ci variables used with db service.
   */
  protected $dbDriver = 'mysql';

  /**
   * Database connection information.
   *
   * @var string
   *   The database URL. This can be overridden by specifying a $DB_URL or a
   *   $SIMPLETEST_DB environment variable.
   *   Default is to the ci variables used with db service.
   */
  protected $dbUrl = 'mysql://drupal:drupal@db/drupal';

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
   *   $DRUPAL_WEB_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $drupalWebRoot = 'web';

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
      '.env.tmpl',
      'phpunit.xml',
    ],
    'ci' => [
      '.phpmd.xml',
      '.phpqa.yml',
      'phpstan.neon',
      'settings.local.php',
    ],
  ];

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

    if (getenv('CI_VERBOSE')) {
      $this->verbose = getenv('CI_VERBOSE');
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
    if (strcmp($this->ciRemoteRef, "/") !== 0) {
      $this->ciRemoteRef .= '/';
    }

    // Pull a DB_URL from the environment, if it exists.
    if (filter_var(getenv('DB_URL'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('DB_URL');
    }
    // Pull a SIMPLETEST_DB from the environment, if it exists.
    if (filter_var(getenv('SIMPLETEST_DB'), FILTER_VALIDATE_URL)) {
      $this->dbUrl = getenv('SIMPLETEST_DB');
    }
    if (getenv('DB_DRIVER')) {
      $this->dbDriver = getenv('DB_DRIVER');
    }

    // Pull a DOC_ROOT from the environment, if it exists.
    if (getenv('DOC_ROOT')) {
      $this->docRoot = getenv('DOC_ROOT');
    }
    // Pull a DRUPAL_WEB_ROOT from the environment, if it exists.
    if (getenv('DRUPAL_WEB_ROOT')) {
      $this->drupalWebRoot = getenv('DRUPAL_WEB_ROOT');
    }
    // Pull a WEB_ROOT from the environment, if it exists.
    if (getenv('WEB_ROOT')) {
      $this->webRoot = getenv('WEB_ROOT');
    }
    else {
      $this->webRoot = $this->docRoot . '/' . $this->drupalWebRoot;
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
   * Mirror our module/theme in the Drupal or the project.
   */
  public function ciPrepare() {
    $this->ciPreparePhpunit();
    $this->ciGetConfigFiles();
    $this->ciPrepareFolders();
  }

  /**
   * Setup Drupal or import a db dump if available.
   *
   * @param string $profile
   *   (optional) The profile to install, default to minimal.
   * @param string $dump
   *   (optional) Dump file if profile is 'dump'.
   */
  public function drupalInstall($profile = 'minimal', $dump = NULL) {
    // Ensure permissions.
    $dir = $this->webRoot . '/sites/default/files';
    $this->taskFilesystemStack()
      ->mkdir($dir)
      ->chown($dir, 'www-data', TRUE)
      ->chgrp($dir, 'www-data', TRUE)
      ->chmod($dir, 0777, 0000, TRUE)
      ->run();

    if ('dump' === $profile && $dump) {
      if ($filename = $this->drupalPrepareDump($dump)) {
        $this->drupalImportDump($filename);
      }
    }
    else {
      $this->ciLog("Install Drupal profile $profile with Drush.");
      $this->drupalSetup($profile);
    }

    $this->drupalCheck();
  }

  /**
   * Add Drupal dev third party for dev.
   *
   * @param string $SKIP_TEST_BEHAT
   *   (optional) Skip behat flag to check if we install behat dependency.
   */
  public function drupalRequireDev($SKIP_TEST_BEHAT = "1") {
    if (!file_exists($this->ciProjectDir . '/vendor/bin/drush')) {
      $this->composerRequire()
          ->dependency('drush/drush', '>10')
          ->run();
    }
    $task = $this->composerRequire()
      ->dependency('drupal/core-dev', '~' . $this->ciDrupalVersion)
      ->dependency('phpspec/prophecy-phpunit', '^2');

    if ($SKIP_TEST_BEHAT == "0") {
      $task
        ->dependency('drupal/drupal-extension', '~4.1')
        ->dependency('dmore/behat-chrome-extension', '^1.3')
        ->dependency('emuse/behat-html-formatter', '0.2.*')
        ->dependency('friends-of-behat/mink-extension', '^2.6')
        ->dependency('dmore/chrome-mink-driver', '2.8.1-beta1');
    }

    $task
      ->dev()
      ->run();
  }

  /**
   * Prepare dump file to use for Drupal install.
   *
   * @param string $dump
   *   Dump file, can be local or remote.
   *
   * @return string|null
   *  Local extracted filename to use for dump.
   */
  private function drupalPrepareDump($dump) {

    $this->ciNotice("Installing Drupal with dump file $dump...");

    $this->drupalCopySettingsLocal();

    if (substr($dump, 0, 4) === 'http') {
      if ($remote_file = file_get_contents($dump)) {
        $filename = sys_get_temp_dir() . DIRECTORY_SEPARATOR . $dump;
        file_put_contents($filename, $remote_file);
      }
      else {
        $this->io()->error("Failed to get remote dump file: $dump");
        return NULL;
      }
    }
    else {
      $filename = $this->ciProjectDir . DIRECTORY_SEPARATOR . $dump;
      if (!file_exists($filename)) {
        $this->io()->error("Cannot find dump file $filename");
        return NULL;
      }
    }

    // Extract dump (gz and zip).
    $infos = pathinfo($filename);
    $exec = NULL;
    if ('gz' === $infos['extension']) {
      $exec = 'zcat ' . $filename . ' > ' . $infos['dirname'] . DIRECTORY_SEPARATOR . $infos['filename'] . ';';
    }
    elseif ('zip' === $infos['extension']) {
      $exec = 'unzip -fo ' . $filename . ';';
    }
    else {
      $this->io()->error("Unknown file extension " . $infos['extension'] . ", this script only support gz or zip.");
      return NULL;
    }

    $this->ciLog("Extract dump $filename");
    $this->_exec($exec);

    return $infos['dirname'] . DIRECTORY_SEPARATOR . $infos['filename'];
  }

  /**
   * Prepare Drupal settings with a dump import.
   */
  private function drupalCopySettingsLocal() {
    $task = $this->taskFilesystemStack();
    // When install from dump we need to be sure settings.php is correct.
    if (!file_exists($this->webRoot . '/sites/default/settings.local.php')) {
      $task
        ->copy($this->ciProjectDir . '/.gitlab-ci/settings.local.php', $this->webRoot . '/sites/default/settings.local.php', TRUE);
    }

    $task
      ->remove($this->webRoot . '/sites/default/settings.php')
      ->copy($this->webRoot . '/sites/default/default.settings.php', $this->webRoot . '/sites/default/settings.php', TRUE)
      ->appendToFile($this->webRoot . '/sites/default/settings.php', 'include $app_root . "/" . $site_path . "/settings.local.php";');
  
    $task->run();
  }

  /**
   * Import a dump file in db based on DB_DRIVER.
   *
   * @param string $filename
   *   Local path to filename dump.
   */
  private function drupalImportDump($filename) {
    $this->ciLog("Import dump $filename with $this->dbDriver");

    switch ($this->dbDriver) {
      case 'mysql':
        $this->_exec('mysql -h db -u root drupal < ' . $filename . ';');
        break;
      case 'pgsql':
        $this->_exec('psql -h db -U drupal -d drupal -f ' . $filename . ';');
        break;
      default:
        $this->io()->error("Db driver $this->dbDriver is not supported by this script.");
    }
  }

  /**
   * Helper for preparing a composer require task.
   *
   * @return \Robo\Task\Composer\RequireDependency
   *   Robo composer require task with some specific settings.
   */
  private function composerRequire() {
    $task = $this->taskComposerRequire()
      ->noInteraction()
      ->option('with-all-dependencies');

    if ($dir) {
      $task->workingDir($dir);
    }

    if ($this->verbose) {
      $task->option('verbose');
    }

    return $task;
  }

  /**
   * Check Drupal status with drush.
   *
   * @return string
   *   Drupal bootstrap result.
   */
  private function drupalCheck() {
    return $this->ciDrush()
      ->args('status')
      ->option('fields', 'bootstrap', '=')
      ->run();
  }

  /**
   * Install Drupal from profile or config with config_installer.
   *
   * @param string $profile
   *   (Optional) The profile to install, default to minimal.
   */
  private function drupalSetup($profile = 'minimal') {
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
   * Mirror our module/theme in the Drupal or the project.
   */
  private function ciPrepareFolders() {

    $this->ciLog("Prepare folders for type: $this->ciType");

    // Handle CI Type value.
    switch ($this->ciType) {
      case "project":
        $this->ciLog("Project include Drupal, symlink to included Drupal.");
        $this->taskFilesystemStack()
          ->remove($this->docRoot)
          ->symlink($this->ciProjectDir, $this->docRoot)
          ->run();
        break;

      case "module":
      case "theme":
      case "profile":
        // If we have a custom build, run it now, see issue:
        // https://gitlab.com/mog33/gitlab-ci-drupal/-/issues/32
        $this->ciBuild();
        // Root contain the theme / module, we mirror with project name.
        $this->taskFilesystemStack()
          ->symlink(
            $this->ciProjectDir,
            $this->webRoot . '/' . $this->ciType . 's/custom/' . $this->ciProjectName
          )->run();
        break;
    }
  }

  /**
   * Setup Phpunit file used for tests.
   */
  private function ciPreparePhpunit() {
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
  }

  /**
   * Get local or remote config files for the CI project.
   */
  private function ciGetConfigFiles() {
    $this->ciLog("Prepare config files for CI");

    $src_dir = $this->ciProjectDir . '/.gitlab-ci/';
    $dest_dir = $this->ciProjectDir . '/' . $this->drupalWebRoot . '/core/';

    // Create directory if do not exist.
    $this->_mkdir($src_dir);

    // Manage files for drupal_root/core folder.
    foreach ($this->ciFiles['core'] as $filename) {
      // Use local file if exist.
      if (file_exists($src_dir . $filename)) {
        $this->ciNotice("Use local core file: $src_dir" . "$filename");
        $this->taskFilesystemStack()
          ->copy($src_dir . $filename, $dest_dir . $filename, TRUE)
          ->run();
      }
      else {
        $this->ciNotice("Download remote core file: $this->ciRemoteRef" . "$filename");
        $remote_file = file_get_contents($this->ciRemoteRef . $filename);
        if ($remote_file) {
          file_put_contents($dest_dir . $filename, $remote_file);
        }
        else {
          $this->io()->warning("Failed to get remote core file: $this->ciRemoteRef" . "$filename");
        }
      }
    }

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
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  private function ciDrush() {
    if (!file_exists($this->ciProjectDir . '/vendor/bin/drush')) {
      $task = $this->composerRequire()
        ->dependency('drush/drush', '>10')
        ->run();
    }

    // Drush needs an absolute path to the webroot.
    $task = $this->taskExec($this->ciProjectDir . '/vendor/bin/drush')
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

}
