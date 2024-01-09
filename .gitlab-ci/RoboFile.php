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
  protected $ciVerbose = FALSE;

  /**
   * Database connection information.
   *
   * @var string
   *   The database driver. This can be overridden by specifying a $CI_DB_DRIVER.
   *   Default is to the ci variables used with db service.
   */
  protected $ciDbDriver = 'mysql';

  /**
   * Database connection information.
   *
   * @var string
   *   The database URL. This can be overridden by specifying a $SIMPLETEST_DB
   *   environment variable.
   *   Default is to the ci variables used with db service.
   */
  protected $dbUrl = 'mysql://drupal:drupal@db/drupal';

  /**
   * Web server docroot folder.
   *
   * @var string
   *   The docroot folder of Drupal. This can be overridden by specifying a
   *   $CI_DOC_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $ciDocRoot = '/opt/drupal';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder of Drupal. This can be overridden by specifying a
   *   $CI_DRUPAL_WEB_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $ciDrupalWebRoot = 'web';

  /**
   * Drupal webroot folder.
   *
   * @var string
   *   The webroot folder of Drupal. This can be overridden by specifying a
   *   $CI_WEB_ROOT environment variable.
   *   Default is to the ci image value.
   */
  protected $ciWebRoot = '/opt/drupal/web';

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
   * CI_COMPOSER_BIN context.
   *
   * @var string
   *   The CI composer bin directory, default is vendor/bin, can be changed
   *   in composer.json with config: bin-dir.
   */
  protected $ciComposerBin = "vendor/bin";

  /**
   * Configuration files for CI context.
   *
   * @var array
   *   The CI files configuration for jobs from .gitlab-ci folder.
   *   Indexed by destination as 'core' (drupal_root/core/) or 'ci'
   *   (.gitlab-ci/).
   */
  protected $ciFiles = [
    'conf/.env.tpl' => '.gitlab-ci/env.tpl',
    'conf/checkstyle2junit.xslt' => '.gitlab-ci/checkstyle2junit.xslt',
    'conf/phpmd2junit.xslt' => '.gitlab-ci/phpmd2junit.xslt',
    'conf/settings.local.php' => '.gitlab-ci/settings.local.php',
    '.eslintignore' => '.eslintignore',
    '.stylelintignore' => '.stylelintignore',
    'phpunit.xml' => 'phpunit.xml',
    '.phpmd.xml' => '.phpmd.xml',
    '.phpqa.yml' => '.phpqa.yml',
    'phpstan.neon' => 'phpstan.neon',
  ];

  /**
   * CI_DRUPAL_VERSION context.
   *
   * @var string
   *   The drupal version used, look at env values for. This can be
   *   overridden by specifying a $CI_DRUPAL_VERSION environment variable.
   */
  protected $ciDrupalVersion = "10.0";

  /**
   * CI_REMOTE_FILES context.
   *
   * @var string
   *   The address of remote ci config files. This can be overridden by
   *   specifying a $CI_REMOTE_FILES environment variable.
   */
  protected $ciRemoteFiles = "";

  /**
   * RoboFile constructor.
   */
  public function __construct() {
    // Treat this command like bash -e and exit as soon as there's a failure.
    $this->stopOnFail();

    $varsFromEnv = [
      'ciVerbose' => 'CI_VERBOSE',
      'ciType' => 'CI_TYPE',
      'ciProjectDir' => 'CI_PROJECT_DIR',
      'ciProjectName' => 'CI_PROJECT_NAME',
      'ciDrupalVersion' => 'CI_DRUPAL_VERSION',
      'ciRemoteFiles' => 'CI_REMOTE_FILES',
      'ciDbDriver' => 'CI_DB_DRIVER',
      'ciDocRoot' => 'CI_DOC_ROOT',
      'ciDrupalWebRoot' => 'CI_DRUPAL_WEB_ROOT',
      'ciWebRoot' => 'CI_WEB_ROOT',
      'ciComposerBin' => 'CI_COMPOSER_BIN',
      'dbUrl' => 'SIMPLETEST_DB',
    ];
    foreach ($varsFromEnv as $name => $value) {
      $this->$name = getenv($value);
    }

    // Add trailing slash on urls.
    if (strcmp($this->ciRemoteFiles, '/') !== 0) {
      $this->ciRemoteFiles .= '/';
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
   * Get files and prepare folders for CI.
   *
   * @param string $job
   *   CI job name.
   */
  public function ciPrepare($job = '') {
    $this->ciGetConfigFiles();
    $this->ciPrepareFolders();
    // After symlink, move local phpunit.xml file to drupal web/core folder.
    if (FALSE !== strpos($job, 'phpunit')) {
      $this->ciPreparePhpunit();
    }
  }

  /**
   * Setup Drupal or import a db dump if available.
   *
   * @param string $profile
   *   (optional) The profile to install, default to minimal.
   * @param ?string $dump
   *   (optional) Dump file if profile is 'dump'.
   */
  public function drupalInstall($profile = 'minimal', $dump = NULL) {
    // Ensure permissions.
    $dir = $this->ciWebRoot . '/sites/default/files';
    $this->taskFilesystemStack()
      ->mkdir($dir)
      ->chown($dir, 'www-data', TRUE)
      ->chgrp($dir, 'www-data', TRUE)
      ->chmod($dir, 0777, 0000, TRUE)
      ->run();

    if ($dump) {
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
   * @param string $CI_SKIP_TEST_BEHAT
   *   (optional) Skip behat flag to check if we install behat dependency.
   */
  public function drupalRequireDev($CI_SKIP_TEST_BEHAT = "1") {
    if (!file_exists($this->ciProjectDir . '/composer.json') && 'project' === $this->ciType) {
      $this->io()->error("Missing composer.json file at the root of this project.");
      return;
    }

    $_ciDocRoot = $this->ciProjectDir;
    if ('project' !== $this->ciType) {
      $_ciDocRoot = $this->ciDocRoot;
    }

    if (!file_exists($_ciDocRoot . '/' . $this->ciComposerBin . '/drush')) {
      $this->composerRequire($_ciDocRoot)
          ->dependency('drush/drush', '>10')
          ->run();
    }

    $task = $this->composerRequire($_ciDocRoot)
      ->dependency('drupal/core-dev', '~' . $this->ciDrupalVersion)
      ->dependency('phpspec/prophecy-phpunit', '^2');

    if ($CI_SKIP_TEST_BEHAT == "0") {
      if ($this->ciDrupalVersion == "9.5" || $this->ciDrupalVersion == "9.4") {
        $task
          ->dependency('drupal/drupal-extension', '^4.1');
      }
      else {
        $task
          ->dependency('drupal/drupal-extension', '5.0.x-dev');
      }
    }

    $task
      ->dependency('dmore/behat-chrome-extension', '^1.4')
      ->dependency('friends-of-behat/mink-extension', '^2.7')
      ->dependency('dmore/chrome-mink-driver', '^2.9');

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
        $filename = sys_get_temp_dir() . '/' . $dump;
        file_put_contents($filename, $remote_file);
      }
      else {
        $this->io()->error("Failed to get remote dump file: $dump");
        return NULL;
      }
    }
    else {
      $filename = $this->ciProjectDir . '/' . $dump;
      if (!file_exists($filename)) {
        $this->io()->error("Cannot find dump file $filename");
        return NULL;
      }
    }

    // Extract dump (gz and zip).
    $infos = pathinfo($filename);
    $exec = NULL;
    if ('gz' === $infos['extension']) {
      $exec = 'zcat ' . $filename . ' > ' . $infos['dirname'] . '/' . $infos['filename'] . ';';
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

    return $infos['dirname'] . '/' . $infos['filename'];
  }

  /**
   * Prepare Drupal settings with a dump import.
   */
  private function drupalCopySettingsLocal() {
    $task = $this->taskFilesystemStack();
    // When install from dump we need to be sure settings.php is correct.
    if (!file_exists($this->ciWebRoot . '/sites/default/settings.local.php')) {
      $task
        ->copy($this->ciProjectDir . '/.gitlab-ci/settings.local.php', $this->ciWebRoot . '/sites/default/settings.local.php', TRUE);
    }

    $task
      ->remove($this->ciWebRoot . '/sites/default/settings.php')
      ->copy($this->ciWebRoot . '/sites/default/default.settings.php', $this->ciWebRoot . '/sites/default/settings.php', TRUE)
      ->appendToFile($this->ciWebRoot . '/sites/default/settings.php', 'include $app_root . "/" . $site_path . "/settings.local.php";')
      ->run();
  }

  /**
   * Import a dump file in db based on CI_DB_DRIVER.
   *
   * @param string $filename
   *   Local path to filename dump.
   */
  private function drupalImportDump($filename) {
    $this->ciLog("Import dump $filename with $this->ciDbDriver");

    switch ($this->ciDbDriver) {
      case 'mysql':
        $this->_exec('mysql -h db -u root drupal < ' . $filename . ';');
        break;
      case 'pgsql':
        $this->_exec('psql -h db -U drupal -d drupal -f ' . $filename . ';');
        break;
      default:
        $this->io()->error("Db driver $this->ciDbDriver is not supported by this script.");
    }
  }

  /**
   * Helper for preparing a composer require task.
   *
   * @param ?string $dir
   *   Working dir for composer command.
   *
   * @return \Robo\Task\Composer\RequireDependency
   *   Robo composer require task with some specific settings.
   */
  private function composerRequire($dir = NULL) {
    $task = $this->taskComposerRequire()
      ->noInteraction()
      ->option('with-all-dependencies');

    if ($dir) {
      $task->workingDir($dir);
    }

    if ($this->ciVerbose) {
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

    if ($profile == 'existing-config') {
      $task = $this->ciDrush()
        ->args('site:install')
        ->option('existing-config')
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
        $this->ciLog("Project include Drupal, symlink to replace included Drupal.");
        $this->taskFilesystemStack()
          ->remove($this->ciDocRoot)
          ->symlink($this->ciProjectDir, $this->ciDocRoot)
          ->run();
        break;

      case "module":
      case "theme":
      case "profile":
        // If we have a custom build, run it now, see issue:
        // https://gitlab.com/mog33/gitlab-ci-drupal/-/issues/32
        $this->ciBuild();
        $this->ciLog("Symlink code to included Drupal.");
        // Root contain the theme / module, we symlink with project name.
        $this->taskFilesystemStack()
          ->symlink(
            $this->ciProjectDir,
            $this->ciWebRoot . '/' . $this->ciType . 's/custom/' . $this->ciProjectName
          )->run();
        break;
    }
  }

  /**
   * Get local or remote config files for the CI project.
   */
  private function ciGetConfigFiles() {
    $this->ciLog("Prepare config files for CI");

    $this->_mkdir($this->ciProjectDir . '/.gitlab-ci/');

    foreach ($this->ciFiles as $srcFilename => $destFilename) {
      if (file_exists($destFilename)) {
        $this->ciNotice('Use local file: ' . $destFilename);
        continue;
      }
      $this->ciGetRemoteFile($this->ciRemoteFiles . $srcFilename, $destFilename);
    }
  }

  /**
   * Helper to download remote file.
   *
   * @param string $remoteFilename
   * @param string $localFilename
   */
  private function ciGetRemoteFile(string $remoteFilename, string $localFilename) {
    $remoteFile = file_get_contents($remoteFilename);
    if ($remoteFile) {
      $this->ciLog('Get remote file: ' . $remoteFilename . " to " . $localFilename);
      file_put_contents($localFilename, $remoteFile);
    }
    else {
      $this->io()->warning('Failed to get remote file: ' . $remoteFilename);
    }
  }

  /**
   * Copy phpunit file to web/core folder to be used by phpunit jobs.
   */
  private function ciPreparePhpunit() {
    if (!file_exists($this->ciProjectDir . '/phpunit.xml')) {
      $this->ciNotice('No phpunit.xml file at the root of the project, using default file.');
      return;
    }
    $this->taskFilesystemStack()
      ->copy(
        $this->ciProjectDir . '/phpunit.xml',
        $this->ciWebRoot . '/core/phpunit.xml',
        TRUE
      )
      ->run();
  }

  /**
   * Return drush with default arguments.
   *
   * @return \Robo\Task\Base\Exec
   *   A drush exec command.
   */
  private function ciDrush() {
    $bin = $this->ciDocRoot . '/' . $this->ciComposerBin . '/drush';

    if (!file_exists($bin)) {
      $task = $this->composerRequire()
        ->dependency('drush/drush', '>10')
        ->run();
    }

    // Drush needs an absolute path to the webroot.
    $task = $this->taskExec($bin)
      ->option('root', $this->ciWebRoot, '=');

    if ($this->ciVerbose) {
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
    if ($this->ciVerbose) {
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
