### Stages

Jobs are grouped by stages, to override stages, edit your `.gitlab-ci.yml` file.

### Available jobs

Name | Detail | Drupal install | Report
---|---|---|:---:
Build | If a project : `composer install`, can be used to add build steps (composer run-script, grunt, webpack, yarn...) | No | No
Unit, kernel and coverage | Phpunit unit and kernel tests with coverage. Codecov.io support see [Codecov.io support](/advanced-usage/#codecovio-support-in-phpunit-code-coverage) | No | xml and html
Functional | Phpunit functional test (Browser based tests) | No | xml and html
Functional Js | Phpunit functional javascript test (Browser with javascript based tests) | Yes (included) | xml and html
Nightwatch Js | Nightwatch.js javascript test (Browser with javascript based tests), see [Nightwatch.js for Drupal 8/9](/advanced-usage/#nightwatchjs-for-drupal-8-or-9) | Yes (included) | text and html
Security | Symfony security-checker, look at versions in composer.lock | No | text
Behat tests | Support Behat tests from `behat_tests` folder, see [Behat tests for Drupal 8/9](#behat-tests-for-drupal-8-or-9) | Yes | html
Pa11y | Accessibility tests with [Pa11y](https://pa11y.org/), tests are defined in [.gitlab-ci/pa11y-ci.json](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/2.x-dev/.gitlab-ci/) | Yes | text
Code quality | Code sniffer with _Drupal standards_, _Drupal Best practice_s standard. Phpstan, Phpmd, Phpcpd | No | html
Js lint | Javascript check with eslint (as used in Drupal core, with Drupal rules) | No | html
Css lint | Css check with stylelint (as used in Drupal core, with Drupal rules) | No | text
Php metrics | Code metrics ans stats in a nice html report with phpmetrics, phploc, pdepend | No | html
Deploy to... | Sample of deploy jobs with ssh to a host | No | No

### CI image tools

Most tools are included in a specific [docker image](https://gitlab.com/mog33/drupal8ci).

Nothing could be done without a bunch of awesome humans building awesome tools.

- [Robo](https://robo.li)
- [Eslint](https://eslint.org/)
- [Stylelint](https://github.com/stylelint/stylelint)
- [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch)
- [PHPunit](https://phpunit.de)
- [Security-checker](https://github.com/sensiolabs/security-checker)
- [Behat](http://behat.org/en/latest)
- [Pa11y](https://pa11y.org)

Code quality is done using the wonderful Phpqa, a tool that integrate other Php
quality and analysis tools:

- [Phpqa](https://github.com/EdgedesignCZ/phpqa)
  - [Phploc](https://github.com/sebastianbergmann/phploc)
  - [Phpcpd](https://github.com/sebastianbergmann/phpcpd)
  - [PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer)
  - [Phpmd](https://github.com/phpmd/phpmd)
  - [PHP-Parallel-Lint](https://github.com/JakubOnderka/PHP-Parallel-Lint)
  - [Pdepend](https://pdepend.org/)
  - [Phpmetrics](https://www.phpmetrics.org)
  - [Phpstan](https://github.com/phpstan/phpstan)
  - [Phpstan for Drupal code](https://github.com/mglaman/phpstan-drupal)

### Custom configuration

You can override any config by copying the file from `.gitlab-ci` folder on your project.

For example if you want to provide your own `phpunit.xml` file, simply add it on your
project in a `.gitlab-ci/` folder.

### Keep jobs artifacts

By default the configuration is to keep each job report **1 week**.

!!! bug "Artifacts override"
    There is currently no easy override for this until https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/1893.

### Custom build

To add some custom build steps for the `Build` job (ie: Yarn, Gulp, Composer, Bower, Webpack...)
you can copy the `.gitlab-ci\build.php` file and include any task.

I use [Robo.li](https://robo.li/) with this [RoboFile](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/2.x-dev/.gitlab-ci/RoboFile.php)
for running some specific ci tasks and Drupal install.

For `CI_TYPE` **project**, this file is executed directly during the Build job
script after the regular `composer install`.

For `CI_TYPE` **module**, this file is executed on each `before_script` part of
jobs.

It's important to have any action relative to the `docRoot` or `webRoot` as we
are not working from the `CI_PROJECT_DIR`.

!!! caution "build.php syntax is not checked"
    If your `build.php` contains error, it will make the `Build` job fail.

Some examples of common tasks:

```php
$this->taskPack('build.zip')
  ->add('vendor')
  ->add('web')
  ->run();

// Run a gulp task.
$this->taskGulpRun()
  ->dir($this->webRoot . 'themes/my_theme_with_gulp_task')
  ->run();

// Add a module (in case of CY_TYPE="module") and your module
// rely on other contrib modules.
$this->taskComposerRequire()
  ->noInteraction()
  ->noAnsi()
  ->workingDir($this->docRoot);
  ->dependency('drupal/webform', '^5.13')
  ->run();

// Or shortcut method in the RoboFile.php with this project:
$this->composerRequire()
 ->dependency('drupal/webform', '^5.13')
 ->run();
```

### Build with private repositories

You can use private repositories in your `composer.json` adding a ssh private key as a variable with name `CI_BUILD_KEY`

See https://getcomposer.org/doc/05-repositories.md#using-private-repositories

The `CI_BUILD_KEY` is an arbitrary named variable for this project to be able to have a private key during the ci job of build that identify the ci user when trying to access a remote address with ssh support.

The CI will access the private module by `SSH` using a private key created from this variable `CI_BUILD_KEY`.

The private key can not have a password so for obvious security reason you must create a key pair only for this task:

1. Generate a ssh key, see [documentation](https://gitlab.com/help/ssh/README)
2. On the *private* Gitlab project (Settings > Repository > Deploy keys) create a Deploy key and paste the __public__ key
3. On the Gitlab where the CI is running (Settings > CI/CD > VARIABLES), add a variable with key `CI_BUILD_KEY` and for value the __private__ part of the key, set the *protect* option depending your use case, do not mask it will never appear in logs

The CI will use this key for any external authentication.

### Nightwatch.js

Since Drupal 8.6, [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch) is included as a Javascript test framework.

For now it is not really ready to be used as a replacement for _functional Javascript_, but soon...

The CI tests here include a patch to be able to install Drupal from a profile for Drupal < 8.9:

- [Support install profile and language code params in drupalInstall Nightwatch command](https://drupal.org/node/3017176)

There is a variable in this project that you can set in Gitlab to select the
tests Nightwatch will run:

Name | Value | Detail
-|-|-
NIGHTWATCH_TESTS | --tag my_module | Only my module tests if set a @tag
NIGHTWATCH_TESTS | --skiptags core | All tests except core.

### Behat tests

Tests for [Behat](http://behat.org) are executed from the `behat_tests/` folder of the
project.

Copy this folder on the root of your project and adapt `behat_tests/features` to your
tests.

To choose the Drupal profile for installation, you can set the `BEHAT_INSTALL_PROFILE` variable.

Name | Value
-|-
BEHAT_INSTALL_PROFILE | standard

For Behat, Selenium is not needed thanks to the
[Behat Chrome extension.](https://gitlab.com/DMore/behat-chrome-extension.git).

Html output of the Behat report is done thanks to
[Behat Html formatter plugin](https://github.com/dutchiexl/BehatHtmlFormatterPlugin).

If you need different configuration for Behat, you can look and override variable
`BEHAT_PARAMS` in `variables_test.yml`

### PHPunit tests

The pipeline in this project support Unit, Kernel, Functional,
[Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial)
tests in Drupal 8/9, see
[Type of tests in Drupal 8/9](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

The tests configuration is defined in [.gitlab-ci/phpunit.xml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/2.x-dev/.gitlab-ci/phpunit.xml).

There is 2 set of tests location:

- Custom modules and themes only, those are prefixed with `custom` in `phpunit.xml`, as `customunit, customkernel, customfunctional, customfunctional-javascript`
  - All `tests/` from `modules/custom/**` and `themes/custom/**`
- Drupal core tests, will look in all folders, defined as `unit, kernel, functional, functional-javascript` are not really used and test coverage do not match this scenario.

There is a Gitlab variable to select the tests:

Name | Value
-|-
PHPUNIT_TESTS | custom

Set this variable _empty_ to run all tests.

To override the configuration you can copy [.gitlab-ci/phpunit.xml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/2.x-dev/.gitlab-ci/phpunit.xml) in your project
and adapt for your tests.

### Codecov.io support

Code coverage job support [Codecov.io](https://codecov.io/).

After creating an account on [Codecov.io](https://codecov.io/), create from the
**Gitlab UI** _> Settings > CI/CD > Variables_ a variable `CODECOV_TOKEN` with
your token value.

### Code Quality

All rules try to match a [Drupal 8 / 9](https://www.drupal.org) project.

To adapt some rules, first look at `.gitlab-ci/.phpqa.yml`, `.gitlab-ci/.phpmd.xml`, `.gitlab-ci/phpstan.neon`.

Copy those files in your project `.gitlab-ci` folder to override.

More options see:

- [Phpqa configuration](https://github.com/EdgedesignCZ/phpqa#advanced-configuration---phpqayml)
- [Phpqa .phpqa.yml](https://github.com/EdgedesignCZ/phpqa/blob/master/.phpqa.yml)
- [Phpstan phpstan.neon](https://phpstan.org/config-reference)
- [Phpmd phpmd.xml](https://phpmd.org/rules/index.html)

#### Phpstan

As a starting point to adapt Phpstan rules for your code, copy the `.gitlab-ci/phpstan.neon` file from this project
to your `.gitlab-ci/`.

##### Ignore errors

To ignore some errors as false positive for Drupal, uncomment the `ignoreErrors:` part of the phpstan.neon file.

Ignore errors that are not in your code will still trigger errors because of unmatched, uncomment
`reportUnmatchedIgnoredErrors: false` to ignore unmatched ignored errors.

##### Autoloading

Phpstan autoloading is based on the project autoloading for Drupal. Contrib modules or themes
folders are not included in the Phpstan analysis. Above level 5, this will trigger a lot of
unknown type hint from Phpstan.

To autoload contrib code, copy the `.gitlab-ci/phpstan.neon` file from this project to your `.gitlab-ci/`
folder and add the parameter [scanDirectories or scanFiles](https://phpstan.org/user-guide/discovering-symbols#third-party-code-outside-of-composer-dependencies),
with absolute path based on `/var/www/html/web` for example:

```yaml
includes:
    - /var/www/.composer/vendor/mglaman/phpstan-drupal/extension.neon
parameters:
    drupal:
        drupal_root: /var/www/html
    scanDirectories:
        - /var/www/html/web/modules/contrib/webform/
```

### Rules for linting

Eslint is based on the official
[Drupal 8/9 eslintrc.passing.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.eslintrc.passing.json)

Stylelint is based on the official
[Drupal 8/9 stylelintrc.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.stylelintrc.json)

_Note:_ As this project is meant for Drupal, there is no override for those files.

### Metrics jobs

Metrics jobs are using [Phpmetrics](https://www.phpmetrics.org), [Phploc](https://github.com/sebastianbergmann/phploc) and [Pdepend](https://pdepend.org/).

_Note:_ Currently this project do not support analyzing coverage for Pdepend and junit
report from Phpunit tests for Phpmetrics.

### Accessibility with Pa11y

Accessibility tests with [Pa11y](https://pa11y.org/), tests are defined in
[.gitlab-ci/pa11y-ci.json](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/2.x-dev/.gitlab-ci/pa11y-ci.json)

For setting your urls to test, adapt the urls section:

```json
  "urls": [
    {
      "url": "http://localhost",
      "screenCapture": "pa11y-home.png"
    }
  ]
```

When a test failed, a screen capture is recorded in the reports.

To choose the Drupal profile for installation, you can set the `PA11Y_INSTALL_PROFILE` variable.

Name | Value
-|-|
PA11Y_INSTALL_PROFILE | standard

### Composer config

In case you want to set a different url for packagist or set a _Github oauth token_, you can set variables:

Name | Detail | Default
-|-|-
COMPOSER_REPO_PACKAGIST_URL | https://getcomposer.org/doc/01-basic-usage.md#packagist | https?://repo.packagist.org
COMPOSER_GITHUB_OAUTH_TOKEN | https://getcomposer.org/doc/06-config.md#github-oauth |

_Note_: The Github token must be a private variable.

### Yarn config

In case you want to set a different url for yarn registry, you can set variables:

Name | Default
-|-
YARN_REGISTRY | https://registry.yarnpkg.com

### All in one report

[WIP]

A report of all tests in one job can be used through a simple dashboard job.

To test it, add this to your `.gitlab-ci.yml` file.

```yaml
stages:
  - build
  - tests
  - metrics
  - reports

pages:
  stage: reports
  extends: .simple_dashboard
  rules:
    - when: always
```

This report can include some status if you add a Gitlab token with `read_api`
from your account as a variable in Gitlab UI:

* Gitlab CI UI > settings > CI/CD

Name | Value
-|-
MY_GITLAB_TOKEN | Gitlab token with `read_api`

### Release of code to Gitlab and Drupal.org

[WIP]

Gitlab release, waiting for:

* https://gitlab.com/gitlab-org/release-cli/-/blob/master/docs/index.md#using-this-tool-in-gitlab-ci

Drupal release based on semantic-release not yet implemented, wip in `.gitlab-ci/ci/06_release.yml`

### Deploy

To deploy to an external server, you must implement your own solution.

As per Drupal 8/9 good practices it is not meant to deploy any database,
only the codebase.

This project include a sample assuming you can ssh to a remote host.  
From this starting point, you can include any script to match your deploy
process.

For some examples, see the documentation: [https://docs.gitlab.com/ee/ci/examples/README.html](https://docs.gitlab.com/ee/ci/examples/README.html)

#### Deploy SSH sample

SSH / SCP based deploy sample job for a project.

Could be a starting point if you have a remote ssh access to your environment.

You must fill variables on the deploy job or in Gitlab UI:
* Gitlab CI UI > settings > CI/CD

See Gitlab-CI Environments documentation:
https://docs.gitlab.com/ee/ci/environments.html#configuring-environments

For deploy samples, see examples in documentation:
https://docs.gitlab.com/ee/ci/examples/README.html

```yaml
Deploy ssh:
  stage: deploy
  extends: .deploy_ssh
  environment:
    name: testing
    url: https://SET_MY_URL
  # To make this deploy job manual on the pipeline.
  # https://docs.gitlab.com/ee/ci/environments.html#configuring-manual-deployments
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
    # Create remote path and send build.
    - ssh -p22 ${ENV_USER}@${ENV_HOST} "mkdir ${ENV_PATH}/_tmp"
    - scp -P22 -r vendor web ${ENV_USER}@${ENV_HOST}:${ENV_PATH}/_tmp
    # Replace Drupal with new build and keep previous version.
    - ssh -p22 ${ENV_USER}@${ENV_HOST} "mv ${ENV_PATH}/current ${ENV_PATH}/_previous && mv ${ENV_PATH}/_tmp ${ENV_PATH}/current"
    # Run any personal deploy script (backup db, drush updb, drush cim...)
    - ssh -p22 ${ENV_USER}@${ENV_HOST} "${ENV_PATH}/scripts/deploy.sh --env=testing"
```
