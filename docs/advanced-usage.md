### Stages

Jobs are grouped by stages, to override stages, edit your `.gitlab-ci.yml` file.

### Available jobs

| Name | Detail | Drupal install | Report |
|---|---|---|:---:|
| Build | If a project : `composer install`, can be used to add build steps (composer run-script, grunt, webpack, yarn...) | No | No |
| Unit, kernel and coverage | Phpunit unit and kernel tests with coverage. Codecov.io support see [Codecov.io support](/advanced-usage/#codecovio-support-in-phpunit-code-coverage) | No | xml and html |
| Functional | Phpunit functional test (Browser based tests) | No | xml and html |
| Functional Js | Phpunit functional javascript test (Browser with javascript based tests) | Yes (included) | xml and html |
| Nightwatch Js | Nightwatch.js javascript test (Browser with javascript based tests), see [Nightwatch.js for Drupal 8/9](/advanced-usage/#nightwatchjs-for-drupal-8-or-9) | Yes (included) | text and html |
| Security report | Symfony security-checker, look at versions in composer.lock | No | text |
| Behat tests | Support Behat tests from `tests` folder, see [Behat tests for Drupal 8/9](#behat-tests-for-drupal-8-or-9) | Yes | html |
| Pa11y | Accessibility tests with [Pa11y](https://pa11y.org/), tests are defined in [.gitlab-ci/pa11y-ci.json](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/8.x-2-dev/.gitlab-ci/) | Yes | text |
| Code quality | Code sniffer with _Drupal standards_ | No | html |
| Best practices | Code sniffer with _Drupal Best practices standard_ | No | html |
| Js lint | Javascript check with eslint (as used in Drupal core, with Drupal rules) | No | html |
| Css lint | Css check with stylelint (as used in Drupal core, with Drupal rules) | No | text |
| Php metrics | Code metrics in a nice html report with phpmetrics | No | html |
| Php stats | Code stats with phploc, pdepend | No | html |
| Deploy to... | Sample of deploy jobs with ssh to a host | No | No |

### CI image tools

All tools are included in a specific [docker image](https://gitlab.com/mog33/drupal8ci).

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

### Custom configuration

You can override any config by copying the file from `.gitlab-ci` folder on your project.

For example if you want to provide your own `phpunit.xml` file, simply add it on your
project in a `.gitlab-ci/` folder.

### Keep jobs artifacts

By default the configuration is to keep each job report **1 week**.

!!! bug "Artifacts override"
    There is currently no easy override for this until https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/1893.

### Custom build

To add some custom build steps for the `Build` job (ie: Yarn, Gulp, composer run, Bower, Webpack...)
you can copy the `.gitlab-ci\build.php` file and include any task.

I use [Robo.li](https://robo.li/) with this [RoboFile](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/8.x-2-dev/.gitlab-ci/RoboFile.php)
for running some specific ci tasks and Drupal install.

### Custom deploy

You can take a look in `.gitlab-ci.yml` for the `Deploy samples` section as a first step of editing to match your project.

### Nightwatch.js

Since Drupal 8.6, [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch) is included as a Javascript test framework.

For now it is not really ready to be used as a replacement for _functional Javascript_, but soon...

The CI tests here include a patch to be able to install Drupal from a profile for Drupal < 8.9:

- [Support install profile and language code params in drupalInstall Nightwatch command](https://drupal.org/node/3017176)

There is a variable in this project that you can set in Gitlab to select the
tests Nightwatch will run:

| Name | Value | Detail |
|-|-|-|
| NIGHTWATCH_TESTS | --tag my_module | Only my module tests if set a @tag |
| NIGHTWATCH_TESTS | --skiptags core | All tests except core. |

### Behat tests

Tests for [Behat](http://behat.org) are executed from the `behat_tests/` folder of the
project.

Copy this folder on the root of your project and adapt `behat_tests/features` to your
tests.

For Behat, Selenium is not needed thanks to the
[Behat Chrome extension.](https://gitlab.com/DMore/behat-chrome-extension.git).

Html output of the Behat report is done thanks to
[Behat Html formatter plugin](https://github.com/dutchiexl/BehatHtmlFormatterPlugin).

### PHPunit tests

The pipeline in this project support Unit, Kernel, Functional,
[Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial)
tests in Drupal 8/9, see
[Type of tests in Drupal 8/9](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

The tests configuration is defined in [.gitlab-ci/phpunit.xml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/8.x-2-dev/.gitlab-ci/phpunit.xml).

There is 2 set of tests location:

- Custom modules and themes only, those are prefixed with `custom` in `phpunit.xml`, as `customunit, customkernel, customfunctional, customfunctional-javascript`
  - All `tests/` from `modules/custom/**` and `themes/custom/**`
- Drupal core tests, will look in all folders, defined as `unit, kernel, functional, functional-javascript` are not really used and test coverage do not match this scenario.

There is a Gitlab variable to select the tests:

| Name | Value |
|-|-|
| PHPUNIT_TESTS | custom |

Set this variable _empty_ to run all tests.

To override the configuration you can copy [.gitlab-ci/phpunit.xml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/8.x-2-dev/.gitlab-ci/phpunit.xml) in your project
and adapt for your tests.

### Codecov.io support

Code coverage job support [Codecov.io](https://codecov.io/).

After creating an account on [Codecov.io](https://codecov.io/), create from the
**Gitlab UI** _> Settings > CI/CD > Variables_ a variable `CODECOV_TOKEN` with
your token value.

### Rules for linting / Code standards

All rules match a [Drupal 8+](https://www.drupal.org) project.

To adapt some rules, first look at `.gitlab-ci/.phpqa.yml`, `.gitlab-ci/.phpmd.xml`.

Copy those files in your project `.gitlab-ci` folder to override.

More options see:

- [Phpqa configuration](https://github.com/EdgedesignCZ/phpqa#advanced-configuration---phpqayml)
- [Phpqa .phpqa.yml](https://github.com/EdgedesignCZ/phpqa/blob/master/.phpqa.yml)

Eslint is based on the official
[Drupal 8/9 eslintrc.passing.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.eslintrc.passing.json)

Stylelint is based on the official
[Drupal 8/9 stylelintrc.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.stylelintrc.json)

### Metrics jobs

Metrics jobs are using [Phpmetrics](https://www.phpmetrics.org), [Phploc](https://github.com/sebastianbergmann/phploc) and [Pdepend](https://pdepend.org/).

### Accessibility with Pa11y

Accessibility tests with [Pa11y](https://pa11y.org/), tests are defined in
[.gitlab-ci/pa11y-ci.json](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/8.x-2-dev/.gitlab-ci/pa11y-ci.json)

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

### Deploy

To deploy to an external server, you must implement your own solution.

As per Drupal 8/9 good practices it is not meant to deploy any database,
only the codebase.

This project include a sample assuming you can ssh to a remote host.  
From this starting point, you can include any script to match your deploy
process.

For some examples, see the documentation: [https://docs.gitlab.com/ee/ci/examples/README.html](https://docs.gitlab.com/ee/ci/examples/README.html)