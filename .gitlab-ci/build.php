<?php

/**
 * @file
 * You can use this file to run extra Robo build tasks.
 *
 * See RoboFile.php and https://robo.li/ documentation to run a task.
 *
 * For CI_TYPE='project', this file is executed directly during the Build job
 * script after the regular composer install.
 *
 * For CI_TYPE='module', this file is executed on each 'before_script' part of
 * jobs.
 *
 * It's important to have any action relative to the docRoot or webRoot as we are
 * not working from the CI_PROJECT_DIR.
 *
 * Examples:
 *
 * $this->say("This will be run in Build script!");
 *
 * $this->taskGulpRun()
 *   ->dir($this->webRoot . 'themes/my_theme_with_gulp_task')
 *   ->run();
 * 
 * $this->taskComposerRequire()
 *   ->noInteraction()
 *   ->noAnsi()
 *   ->workingDir($this->docRoot);
 *   ->dependency('drupal/webform', '^5.13')
 *   ->run();
 *
 * Or shortcut method in the RoboFile.php with this project:
 * $this->composerRequire()
 *  ->dependency('drupal/webform', '^5.13')
 *  ->run();
 *
 */
