<?php

/**
 * @file
 * You can use this file to run extra Robo build tasks.
 *
 * See RoboFile.php and https://robo.li/ documentation to run a task.
 * This file is executed directly during the Build job script, after
 * the regular composer install if a project.
 *
 * Examples:
 *
 * $this->say("This will be run in Build script!");
 *
 * $this->taskPack('build.zip')
 *   ->add('vendor')
 *   ->add('web')
 *   ->run();
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
