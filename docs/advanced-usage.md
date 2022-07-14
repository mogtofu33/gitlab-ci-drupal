### Custom configuration files

You can override any config by copying the file from
[.gitlab-ci](https://gitlab.com/mog33/gitlab-ci-drupal/-/tree/4.x-dev/.gitlab-ci)
folder on your project.

For example if you want to provide your own `phpunit.xml` file, simply add it on your project in a `.gitlab-ci/` folder.

### Keep jobs artifacts

By default the configuration is to keep each job report **1 week**.

!!! bug "Artifacts override"
    There is currently no easy override for this until
    [MR1893](https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/1893).

### Custom build tasks

To add some custom build steps for the `Build` job (ie: Yarn, Gulp, Composer, Bower, Webpack, Babel...) before or after
the regular build steps (composer install/require) you can create `.gitlab-ci\build.php` or
`.gitlab-ci\before_build.php` file and include any task provided by [Robo.li](https://robo.li/tasks/Base/).

File `.gitlab-ci\build.php` is executed during the Build job script after the regular `composer install / require`.

File `.gitlab-ci\before_build.php` is executed during the Build job before any `composer install / require`, it should
not include a composer task but any other task you need before the build.

It's important to have any action relative to the `$this->docRoot` or `$this->webRoot` as we are not working from the
`CI_PROJECT_DIR`.

!!! caution "build.php and before_build.php syntax are not checked"
    If your `build.phCI_COMPOSER_REPO_PACKAGIST_URLp` or `before_build.php` contains error, it will make the `Build` job
    fail!

Some examples of common tasks:

```php
<?php

// Download a remote file:
$myFile = 'https://gitlab.com/mog33/gitlab-ci-drupal/-/raw/4.x-dev/README.md';
if ($this->taskExec("curl -fsSL $myFile -o $this->docRoot . '/README.md")->run()->wasSuccessful()) {
  $this->say('File downloaded!');
}

// Run a gulp task.
$this->taskGulpRun()
  ->dir($this->webRoot . 'themes/my_theme_with_gulp_task')
  ->run();

// Add a module (in case of CY_TYPE="module") and your module
// rely on other contrib modules.
$this->taskComposerRequire()
  ->noInteraction()
  ->noAnsi()
  ->workingDir($this->docRoot)
  ->dependency('drupal/webform', '^5.13')
  ->run();

// Or shortcut method in the RoboFile.php with this project:
$this->composerRequire()
 ->dependency('drupal/webform', '^5.13')
 ->run();
```

For more tasks options see [Robo.li documentation](https://robo.li/tasks/Base/).

### Composer

#### Composer config

If your project set a specific bin dir in composer.json you must adapt the variable:

Name | Detail | Default
-|-|-
`CI_COMPOSER_BIN` | Project bin dir relative | `vendor/bin`

In case you want to set a different url for packagist or set a _Github oauth token_, you can set variables:

Name | Detail | Default
-|-|-
`CI_COMPOSER_REPO_PACKAGIST_URL` | [Packagist repository](https://getcomposer.org/doc/01-basic-usage.md#packagist) | `https://repo.packagist.org`
`CI_COMPOSER_GITHUB_OAUTH_TOKEN` | [Github Oauth](https://getcomposer.org/doc/06-config.md#github-oauth) | -

!!! notice "The Github token MUST be a private variable!"
    Create from the variable from **Gitlab UI** _> Settings > CI/CD > Variables_ a variable
    `CI_COMPOSER_GITHUB_OAUTH_TOKEN` with your token value.

#### Composer packages on private repositories

You can use private repositories in your `composer.json` adding a ssh private key as a variable with name `CI_BUILD_KEY`

See [using private repositories](https://getcomposer.org/doc/05-repositories.md#using-private-repositories).

The `CI_BUILD_KEY` is an arbitrary named variable for this project to be able to have a private key during the ci job of
build that identify the ci user when trying to access a remote address with ssh support.

The CI will access the private module by `SSH` using a private key created from this variable `CI_BUILD_KEY`.

The private key can not have a password so for obvious security reason you must create a key pair only for this task:

1. Generate a ssh key, see [documentation](https://gitlab.com/help/ssh/README)
2. On the **private** Gitlab project (Settings > Repository > Deploy keys) create a Deploy key and paste the **public**
  key
3. On the Gitlab where the CI is running (Settings > CI/CD > VARIABLES), add a variable with key `CI_BUILD_KEY` and for
  value the **private** part of the key, set the **protect** option depending your use case, do not mask it will never
  appear in logs

The CI will use this key for any external authentication.

### PHPunit tests

The pipeline in this project support Unit, Kernel, Functional,
[Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial)
tests in Drupal 9+, see
[Type of tests in Drupal 9+](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

The tests configuration is defined in
[.gitlab-ci/phpunit.xml](https://gitlab.com/mog33/gitlab-ci-drupal/-/raw/4.x-dev/.gitlab-ci/phpunit.xml).
You can set your own specific configuration file with `CI_PHPUNIT_CONFIGURATION` or for a project simply have a
`web/core/phpunit.xml` file.

This project include a specific phpunit configuration, tests are performed only for files from `modules/custom/**` and
`themes/custom/**`.

There is a Gitlab variable to select the tests and optional group:

Name | Value | Default
-|-|-
`CI_PHPUNIT_GROUP` | my_group_tests | -
`CI_PHPUNIT_CONFIGURATION` | configuration file folder | `web/core/`

### Codecov.io support

Code coverage job support [Codecov.io](https://codecov.io/).

After creating an account on [Codecov.io](https://codecov.io/), create from the
**Gitlab UI** _> Settings > CI/CD > Variables_ a variable `CI_CODECOV_TOKEN` with
your token value.

### Code Quality

All rules try to match a [Drupal 9+](https://www.drupal.org) project.

To adapt some rules, first look at `.gitlab-ci/.phpmd.xml`, `.gitlab-ci/phpstan.neon`.

Copy those files in your project root and configure variables to override or place in a specific
folder and adapt variables below.

Name | Detail |  Value
-|-|-
`CI_QA_CONFIG_PHPSTAN` | [PHPStan config reference](https://phpstan.org/config-reference) | `${CI_PROJECT_DIR}/phpstan.neon`
`CI_QA_CONFIG_PHPMD` | [Phpmd rules](https://phpmd.org/rules/index.html) | `${CI_PROJECT_DIR}/.phpmd.xml`

#### PHPMD

If a generated baseline file is on the same level as `phpmd.xml`, it will be included, see
[phpmd.org documentation](https://phpmd.org/documentation/).

#### PHPStan

As a starting point to adapt PHPStan rules for your code, copy the `.gitlab-ci/phpstan.neon` file from this project to
your `.gitlab-ci/` or to the root of your project and change `CI_QA_CONFIG_PHPSTAN`.

##### Ignore errors

To ignore some errors as false positive for Drupal, create a `ignoreErrors:` section in your `phpstan.neon` file.

See [ignoring errors](https://phpstan.org/user-guide/ignoring-errors).

Ignore errors that are not in your code will still trigger errors because of unmatched, uncomment
`reportUnmatchedIgnoredErrors: false` to ignore unmatched ignored errors.

##### Baseline

To include a baseline file you must adapt `phpstan.neon` with your baseline file.

See [PHPStan baseline](https://phpstan.org/user-guide/baseline)

##### Autoloading

PHPStan autoloading is based on the project autoloading for Drupal. Contrib modules or themes
folders are not included in the PHPStan analysis. Above level 5, this will trigger a lot of
unknown type hint from PHPStan.

To autoload contrib code, copy the `.gitlab-ci/phpstan.neon` file from this project at the root or fill a
`CI_QA_CONFIG_PHPSTAN` variable to point the ci to this configuration.

Then add the parameter
[scanDirectories or scanFiles](https://phpstan.org/user-guide/discovering-symbols#third-party-code-outside-of-composer-dependencies),
with absolute path based on `/opt/drupal/web` for example:

```yaml
parameters:
    scanDirectories:
        - /opt/drupal/web/modules/contrib/webform/
```

### Linting JavaScript, CSS and Yaml

Eslint is based on the official
[Drupal 9+ eslintrc.passing.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.eslintrc.passing.json)

Stylelint is based on the official
[Drupal 9+ stylelintrc.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.stylelintrc.json)

You can adapt rule file used for each job.

Name | Value
-|-
`CI_CONFIG_ESLINT` | `${CI_WEB_ROOT}/core/.eslintrc.passing.json`
`CI_CONFIG_ESLINT_YAML` | `${CI_WEB_ROOT}/core/.eslintrc.passing.json`
`CI_CONFIG_STYLELINT` | `${CI_WEB_ROOT}/core/.stylelintrc.json`

Name | Value
-|-
`CI_CONFIG_ESLINT_IGNORE` | `${CI_PROJECT_DIR}/.eslintignore`
`CI_CONFIG_ESLINT_IGNORE_YAML` | `${CI_PROJECT_DIR}/.eslintignore`
`CI_CONFIG_STYLELINT_IGNORE` | `${CI_PROJECT_DIR}/.stylelintignore`

If your project use specific `package.json` and **Node bin dir**, see variables for Node below.

#### Files concerned by linting

Space separated for multiple folders. Default is all custom code.

Name | Value
-|-
`CI_DIRS_LINT_JS` | `${CI_WEB_ROOT}/**/custom/**/*.js`
`CI_DIRS_LINT_YAML` | `${CI_WEB_ROOT}/**/custom/**/*.yml`
`CI_DIRS_LINT_CSS` | `${CI_WEB_ROOT}/**/custom/**/css/*.css`

#### Node / Yarn config

If your project use a specific package.json for lint jobs you must adapt the variable:

Name | Detail | Default
-|-|-
`CI_LINT_NODE_PACKAGE` | Package.json dir | `${CI_WEB_ROOT}/core`
`CI_LINT_NODE_BIN_DIR` | Node bin dir | `${CI_LINT_NODE_PACKAGE}/node_modules/.bin`

In case you want to set a different url for yarn registry, you can set variables:

Name | Default
-|-
`CI_YARN_REGISTRY` | `https://registry.yarnpkg.com`

### Metrics jobs

Metrics jobs are using:

- [Phpmetrics](https://www.phpmetrics.org)
- [Phploc](https://github.com/sebastianbergmann/phploc)
- [Pdepend](https://pdepend.org/)

PHPqa is used to provide a HTML report that you can access from the job artifacts and kept by default 1 week.

You can override `.gitlab-ci/.phpqa.yml`, copy this file at the root of your project or fill a `CI_METRICS_CONFIG_PHPQA`
variable to point the ci to this configuration folder.

Name | Value
-|-
`CI_METRICS_CONFIG_PHPQA` | `${CI_PROJECT_DIR}`

### Nightwatch.js

Since Drupal 8.6, [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch) is included
as a Javascript test framework.

There is a variable in this project that you can set in Gitlab to select the
tests Nightwatch will run:

Name | Value | Detail
-|-|-
`CI_NIGHTWATCH_TESTS` | `--tag my_module` | Only my module tests if set a `@tag`
`CI_NIGHTWATCH_TESTS` | `--skiptags core` | All tests except core.

### Behat tests

Tests for [Behat](http://behat.org) are executed from the `CI_BEHAT_TESTS` variable.

You have to create a folder for your tests at the root of your project containing Behat tests and code.
An example is provided in this project in `behat_tests`, it could be used as a starting point.

Name | Value
-|-
`CI_BEHAT_TESTS` | `${CI_PROJECT_DIR}/behat_tests/behat.yml`

#### Drupal installation for Behat

To install Drupal from a db dump, you need to set `CI_BEHAT_INSTALL_DUMP` variable to a local or remote dump file.

The dump file must be a SQL export (no pg_dump) and can be compressed with gzip or zip.

To choose the Drupal profile for installation, you can set the `CI_BEHAT_INSTALL_PROFILE` variable.

Name | Value
-|-
`CI_BEHAT_INSTALL_PROFILE` | `minimal`
`CI_BEHAT_INSTALL_DUMP` | `my-dump.sql.zip`

For Behat, Selenium is not needed thanks to the
[Behat Chrome extension](https://gitlab.com/DMore/behat-chrome-extension.git).

If you need different configuration for Behat, you can look and override variable
`BEHAT_PARAMS` in
[.gitlab-ci/template/variables.yml](https://gitlab.com/mog33/gitlab-ci-drupal/-/raw/4.x-dev/.gitlab-ci/template/variables.yml)

### Release of code to Gitlab and Drupal.org

[WIP]

Gitlab release, waiting for:

- [Gitlab CLI](https://gitlab.com/gitlab-org/release-cli/-/blob/master/docs/index.md#using-this-tool-in-gitlab-ci)

Drupal release based on semantic-release not yet implemented, wip in `.gitlab-ci/template/04_release.yml`

### Deploy

To deploy to an external server, you must implement your own solution.

As per Drupal 9 good practices it is not meant to deploy any database,
only the codebase.

This project include a sample assuming you can ssh to a remote host.  
From this starting point, you can include any script to match your deploy
process.

For some examples, see the documentation:
[https://docs.gitlab.com/ee/ci/examples/README.html](https://docs.gitlab.com/ee/ci/examples/README.html)

#### Deploy SSH sample

SSH / SCP based deploy sample job for a project.

Could be a starting point if you have a remote ssh access to your environment.

You must fill variables on the deploy job or in Gitlab UI:

- Gitlab CI UI > settings > CI/CD

See Gitlab-CI Environments documentation:
[configuring environments](https://docs.gitlab.com/ee/ci/environments.html#configuring-environments)

For deploy samples, see examples in documentation:
[README](https://docs.gitlab.com/ee/ci/examples/README.html)

```yaml
deploy ssh:
  stage: deploy
  extends: .deploy_ssh
  environment:
    name: testing
    url: https://SET_MY_URL
  # To make this deploy job manual on the pipeline.
  # @see https://docs.gitlab.com/ee/ci/environments.html#configuring-manual-deployments
  # when: manual
  # Variables can be set from 'Gitlab CI UI > settings > CI/CD > variables' as
  # named below or directly here.
  variables:
    ENV_USER: "${TESTING_USER}"
    ENV_HOST: "${TESTING_HOST}"
    ENV_PATH: "${TESTING_PATH}"
    # Adapt if you are using the same key or different ssh keys.
    ENV_KEY: "${PRIVATE_KEY}"
    # ENV_KEY: "${TESTING_PRIVATE_KEY}"
    # ENV_KEY: "${STAGING_PRIVATE_KEY}"
    # ENV_KEY: "${PRODUCTION_PRIVATE_KEY}"
  ##############################################################################
  # Deploy script, this is just an example for scp / ssh remote command for a
  # Drupal project.
  ##############################################################################
  script:
    # Clean dev modules from Drupal
    - composer --no-dev update
    # Create remote path and send build.
    - ssh -p22 ${ENV_USER}@${ENV_HOST} "mkdir ${ENV_PATH}/_tmp"
    # Send files to remote server
    - scp -P22 -r vendor web ${ENV_USER}@${ENV_HOST}:${ENV_PATH}/_tmp
    # Replace Drupal with new build and keep previous version.
    - ssh -p22 ${ENV_USER}@${ENV_HOST} "mv ${ENV_PATH}/current ${ENV_PATH}/_previous && mv ${ENV_PATH}/_tmp ${ENV_PATH}/current"
    # Run any personal deploy script (backup db, drush updb, drush cim...)
    - ssh -p22 ${ENV_USER}@${ENV_HOST} "${ENV_PATH}/scripts/deploy.sh --env=testing"
```

#### [WIP] Deploy Docker image sample

```yaml
deploy image:
  stage: deploy
  extends: .deploy_docker
  variables:
    IMAGE_NAME: "${CI_DEPLOY_IMAGE_NAME}"
    IMAGE_TAG: "${CI_COMMIT_SHORT_SHA}"
  script:
    # Create docker image and include our Drupal code.
    - docker build --compress --tag $CI_REGISTRY_IMAGE/$IMAGE_NAME:$IMAGE_TAG --file ./.gitlab-ci/conf/Dockerfile
    - docker push $CI_REGISTRY_IMAGE/$IMAGE_NAME
    - docker ps
    # Sample to push to Docker Hub.
    # - docker tag $CI_REGISTRY_IMAGE/$IMAGE_NAME $RELEASE_IMAGE/$IMAGE_NAME
    # - echo "$RELEASE_PASSWORD" | docker login $RELEASE_REGISTRY --username $RELEASE_USER --password-stdin
    # - docker push $RELEASE_IMAGE/$IMAGE_NAME
```
