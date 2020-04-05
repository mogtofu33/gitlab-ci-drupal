# Gitlab CI with Drupal 8

Drupal 8.8: [![pipeline status master](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/master)

Drupal 8.9.x-dev: [![pipeline status 8.9.x-dev](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/testing-8.9)

<img src="https://www.drupal.org/sites/all/themes/drupalorg_themes/blueprint/images/logo-d8.svg"  width="120" height="120"> +
<img src="https://about.gitlab.com/images/ci/gitlab-ci-cd-logo_2x.png"  width="120" height="120">

[Gitlab CI](https://docs.gitlab.com/ee/ci/README.html) for a
[Drupal 8](https://www.drupal.org) module / theme or project.

Include **Build**,
**Unit testing**, **Code quality**, **Metrics** and **Deploy** samples.

- [Prerequisites](#prerequisites)
- [Quick how to](#quick-how-to)
  - [Use Gitlab CI with your Drupal 8 module](#use-gitlab-ci-with-your-drupal-8-module)
  - [Use Gitlab CI with your full Drupal project](#use-gitlab-ci-with-your-full-drupal-project)
- [Usage](#usage)
  - [Skip jobs](#skip-jobs)
  - [Triggering pipeline](#triggering-pipeline)
- [Workflow proposed](#workflow-proposed)
  - [Branch master](#branch-master)
  - [Branch testing](#branch-testing)
- [Advanced usage](#advanced-usage)
  - [Nightwatch.js for Drupal 8](#nightwatchjs-for-drupal-8)
  - [Behat tests for Drupal 8](#behat-tests-for-drupal-8)
  - [PHPunit tests for Drupal 8](#phpunit-tests-for-drupal-8)
  - [Codecov.io support in PHPUNIT Code coverage](#codecovio-support-in-phpunit-code-coverage)
  - [Rules for linting / Code standards / QA](#rules-for-linting--code-standards--qa)
  - [Metrics jobs](#metrics-jobs)
  - [Accessibility with Pa11y](#accessibility-with-pa11y)
  - [Deploy](#deploy)
- [Jobs detail](#jobs-detail)
- [CI image including tools](#ci-image-including-tools)
- [Issues](#issues)
- [Future plan](#future-plan)
- [Credits](#credits)

## Prerequisites

- Gitlab CI with a [runner that support docker](https://docs.gitlab.com/runner/)
- Minimal understanding of [Gitlab CI](https://about.gitlab.com/features/gitlab-ci-cd/) and [Gitlab CI Yaml](https://docs.gitlab.com/ee/ci/yaml)

## Quick how to

### Use Gitlab CI with your Drupal 8 module

Push your module to a Gitlab with CI and runners enabled.

[Gitlab.com](https://gitlab.com) offer 2,000 CI pipeline minutes/month on free
accounts.

- Copy `.gitlab-ci.yml` file and `.gitlab-ci` folder in the root of your Drupal module or theme (same level as `my_module_or_theme.info.yml` file).
- Go to Gitlab **Settings > CI/ CD > Variables** and add variables:

```shell
CI_IMAGE_VARIANT        drupal
# 8.7, 8.8 or 8.9 for 8.9.x-dev
CI_DRUPAL_VERSION       8.8
CI_TYPE                 module
WEB_ROOT                /var/www/html
PHP_CODE_QA             /var/www/html/web/modules/custom
PHP_CODE_METRICS        /var/www/html/web/modules/custom
# Security is for a Drupal project with third party.
SKIP_TEST_SECURITY      1
# Only needed if you have Behat tests.
SKIP_TEST_BEHAT         1
# Accessibility tests, more for a Drupal project.
SKIP_TEST_PA11Y         1
# If Nightwatch.js tests, add your tag:
NIGHTWATCH_TESTS        --tag my_module
# Or you can disable Nightwatch tests with:
SKIP_TEST_NIGHTWATCH    1
# If you don't have sass files, you can skip with
SKIP_LINT_SASS          1
# If you don't have any css files, you can skip with
SKIP_LINT_CSS           1
# If you don't have any javascript files, you can skip with
SKIP_LINT_JS            1
```

![gitlab-variables](https://gitlab.com/mog33/gitlab-ci-drupal/uploads/3676704eb083be3edf9035aaadebe10c/gitlab-ci-drupal-variables.jpg)

- Create a branch **8.x-dev** and push to Gitlab.

Check your project pipeline or
[Run a pipeline from Gitlab UI](https://docs.gitlab.com/ee/ci/pipelines.html#manually-executing-pipelines)

- Create a branch **master** and push, see the pipeline running!

As an example you can check my module:
[Content moderation edit notify](https://gitlab.com/mog33/content_moderation_edit_notify)

### Use Gitlab CI with your full Drupal project

Push your project to a Gitlab with CI and runners enabled.

[Gitlab.com](https://gitlab.com) offer 2,000 CI pipeline minutes/month on free
accounts.

Assuming your project include a `composer.json` file from the [Drupal project
template](https://github.com/drupal-composer/drupal-project).

**Note**: should work with other Drupal distributions or project but this is not tested yet.

- Copy `.gitlab-ci.yml` file, `.gitlab-ci` and if you are using _Behat_ the `tests` folders in
the root of your Drupal.
project (same level as `composer.json` file).
- Put your code in the `web/modules/custom` and `web/themes/custom` folders of your project.
- Create a branch **8.x-dev** and push to Gitlab.

Check your project pipeline or
[Run a pipeline from Gitlab UI](https://docs.gitlab.com/ee/ci/pipelines.html#manually-executing-pipelines)

- Create a branch **master** and push, see the pipeline running!

To test against Drupal 8.8.0-beta1 version, go to Gitlab **Settings > CI/ CD > Variables** and add variables:

```shell
CI_DRUPAL_VERSION          8.8
```

Set `8.9` to test against Drupal 8.9.x-dev.

See [Skip jobs](#skip-jobs) to adapt the default jobs.

As an example you can check my project on a Drupal 8 template:
[Drupal 8 project template](https://gitlab.com/mog33/drupal-composer-advanced-template)

## Usage

**Note**: The `.gitlab-ci.yml` file is meant to be a starting point for working
jobs with [Drupal 8](https://www.drupal.org), feel free to cherry pick what you
need but be careful about dependencies between some jobs and templates logic.

If your commit message contains **[ci skip]** or **[skip ci]**, using any
capitalization, the commit will be created but the pipeline will be skipped.

First look in `.gitlab-ci/.gitlab-ci-variables.yml` and check the variables.
This is all the variables you can override from global settings on Gitlab CI or
when manually running a pipeline.

See section [Advanced usage](#advanced-usage) for more details on each relation
between variables and jobs.

### Skip jobs

You can set variables values on Gitlab CI UI under _Settings > CI / CD > Variables_

With variables you can disable some tests without editing any file, available
skip variables are:

```yml
  # Skip all tests jobs (next list).
  SKIP_TESTS: 0
  # Skip single jobs in tests. for tests information see
  # https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8.
  #
  # Phpunit unit,kernel
  SKIP_TEST_UNITKERNEL: 0
  # Phpunit code coverage with optional Codecov.io support
  SKIP_TEST_CODECOVERAGE: 0
  # Phpunit functional tests (browser tests)
  SKIP_TEST_FUNCTIONAL: 0
  # Phpunit functional javascript tests (browser with javascript tests)
  SKIP_TEST_FUNCTIONALJS: 0
  # Nightwatch tests (browser with javascript tests), since Drupal 8.6
  # Currently not fully ready for Drupal.
  SKIP_TEST_NIGHTWATCH: 0
  # Symfony security check on composer.lock
  SKIP_TEST_SECURITY: 0
  # Behat tests
  SKIP_TEST_BEHAT: 0
  # Accessibility test
  SKIP_TEST_PA11Y: 0
  # Skip all QA jobs (Code sniffer with Drupal standards)
  SKIP_QA: 0
  # Skip QA Best practices (Code sniffer with Drupal Practices standard)
  SKIP_QA_BESTPRACTICES: 0
  # Skip all lint jobs (Javascript with eslint, Css with stylelint, Sass with sass-lint)
  SKIP_LINT: 0
  # Skip CSS lint job with stylelint
  SKIP_LINT_CSS: 0
  # Skip Javascript lint job with eslint
  SKIP_LINT_JS: 0
  # Skip single lint sass job (Only one not included in Drupal core)
  SKIP_LINT_SASS: 0
  # Skip all metrics jobs (phpmetrics, phploc, pdepend)
  SKIP_METRICS: 0
  # Skip only Phpmetrics job
  SKIP_METRICS_PHPMETRICS: 0
  # Skip only phploc, pdepend
  SKIP_METRICS_PHPSTATS: 0
  # Skip all deploy jobs by default (samples of deploy)
  SKIP_DEPLOY: 1
```

### Triggering pipeline

If you want to choose when to run the tests, you can adapt rules in
`.gitlab-ci.yml`, see
[Gitlab documentation](https://docs.gitlab.com/ee/ci/yaml/#onlyexcept-basic)

Tests (and Build) are by default on a branches `8.x-dev, 8.x-1.x, testing` and
on all `tags`

```yml
.test_except_only: &test_except_only
  except:
    refs:
      - master
    variables:
      - $SKIP_TESTS == "1"
  only:
    refs:
      - 8.x-1.x
      - 8.x-dev
      - testing
      - tags
```

QA and Lint is run by default on all `branches`, you can adapt on each jobs
by editing `only: except:`

Metrics jobs are by default on each push on `master` and all `tags`.

Deploy jobs are disabled by default, you have to set in **Gitlab UI** a variable:

```shell
SKIP_DEPLOY 0
```

Then deploy jobs run by default on each push on `master` and `tag`. And they are
all set manual by default (must be manually started on the pipeline).

## Workflow proposed

Workflow used with this project, based on Git branches or tags.

By default a new tag or branch _testing_ trigger the build, unit tests,
security, qa, lint, manual deploy to test.
A branch _master_ trigger qa, lint, manual deploy

You can adapt _only_ and _except_ for your own workflow, see
[Gitlab documentation](https://docs.gitlab.com/ee/ci/yaml/#onlyexcept-basic)
and section [Triggering pipeline](#triggering-pipeline)

Deploy jobs are disabled by default, you have to set in **Gitlab UI** a variable:

```shell
SKIP_DEPLOY 0
```

### Branch master

[![gitlab-pipeline-master](https://gitlab.com/mog33/gitlab-ci-drupal/uploads/449abbb2c59e217dc0999621511545e8/gitlab-pipeline-master.png)](https://gitlab.com/mog33/gitlab-ci-drupal/pipelines/73438508)

### Branch testing

[![gitlab-pipeline-testing](https://gitlab.com/mog33/gitlab-ci-drupal/uploads/5971202471b49e1477fdd4ef2cbf1eb6/gitlab-pipeline-testing.png)](https://gitlab.com/mog33/gitlab-ci-drupal/pipelines/73438670)

## Advanced usage

You can take a look in `.gitlab-ci.yml` for the text `[CI_TYPE] [DEPLOY] [TESTING]`
as a first step of editing to match your project.

I use [Robo.li](https://robo.li/) with this [RoboFile](.gitlab-ci/RoboFile.php)
for running composer, phpunit and some specific tasks.

### Nightwatch.js for Drupal 8

Since Drupal 8.6, [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch) is included as a Javascript test framework.

For now it is not really ready to be used as a replacement for _functional
Javascript_, but soon...

The CI tests here include a patch to be able to install Drupal from a profile:

- [Support install profile and language code params in drupalInstall Nightwatch command](https://drupal.org/node/3017176)

There is a variable in this project that you can set in Gitlab to select the
tests Nightwatch will run:

```shell
  # Only my module tests if set a @tag
  NIGHTWATCH_TESTS    --tag my_module
  # All tests except core
  NIGHTWATCH_TESTS    --skiptags core
```

### Behat tests for Drupal 8

Tests for [Behat](http://behat.org) are executed from the `tests/` folder of the
project.

Copy this folder on the root of your project and adapt `tests/features` to your
tests.

For Behat, Selenium is not needed thanks to the
[Behat Chrome extension.](https://gitlab.com/DMore/behat-chrome-extension.git).

Html output of the Behat report is done thanks to
[Behat Html formatter plugin](https://github.com/dutchiexl/BehatHtmlFormatterPlugin).

### PHPunit tests for Drupal 8

The pipeline in this project support Unit, Kernel, Functional,
[Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial)
tests in Drupal 8, see
[Type of tests in Drupal 8](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

The tests are defined in [.gitlab-ci/phpunit.xml](.gitlab-ci/phpunit.xml).
There is 2 set of tests location:

- Custom modules and themes only, those are prefixed with `custom` in `phpunit.xml`, as `customunit, customkernel, customfunctional, customfunctional-javascript`
  - All `tests/` from `modules/custom/**` and `themes/custom/**`
- Drupal core tests, will look in all folders, defined as `unit, kernel, functional, functional-javascript` are not really used and test coverage do not match this scenario.

There is a Gitlab variable to select the tests:

```shell
PHPUNIT_TESTS     custom
```

Set this variable _empty_ to run all tests.

You can edit [.gitlab-ci/phpunit.xml](.gitlab-ci/phpunit.xml) and adapt for your tests or you can create a file named `phpunit.xml.PHPUNIT_TESTS` in [.gitlab-ci](.gitlab-ci) and CI will use it instead of `phpunit.xml` to run the tests.

For example this project use `PHPUNIT_TESTS demo` and so a file `phpunit.xml.demo`
for demo and test purpose.

### Codecov.io support in PHPUNIT Code coverage

Code coverage job support [Codecov.io](https://codecov.io/).

After creating an account on [Codecov.io](https://codecov.io/), create from the
**Gitlab UI** _> Settings > CI / CD > Variables_ a variable `CODECOV_TOKEN` with
your token value.

### Rules for linting / Code standards / QA

All rules match a [Drupal 8](https://www.drupal.org) project.

To adapt some rules, first look at `.gitlab-ci/.phpqa.yml`, `.gitlab-ci/.phpmd.xml`
and `.gitlab-ci/.sass-lint.yml`.

More options see:

- [Phpqa configuration](https://github.com/EdgedesignCZ/phpqa#advanced-configuration---phpqayml)
- [Phpqa .phpqa.yml](https://github.com/EdgedesignCZ/phpqa/blob/master/.phpqa.yml)

Eslint is based on the official
[Drupal 8 eslintrc.passing.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.eslintrc.passing.json)

Stylelint is based on the official
[Drupal 8 stylelintrc.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.stylelintrc.json)

[Sass-lint](.gitlab-ci/.sass-lint.yml) is based on
[Wolox](https://github.com/Wolox/frontend-bootstrap/blob/master/.sass-lint.yml)

A variable define the code to be tested, relative to the web root of the image, the root is `/var/www/html/web`:

```shell
PHP_CODE_QA /var/www/html/web/modules/custom
```

### Metrics jobs

Metrics jobs are using [Phpmetrics](https://www.phpmetrics.org), [Phploc](https://github.com/sebastianbergmann/phploc) and [Pdepend](https://pdepend.org/).

A variable define the code to be tested, relative to the web root of the image, the root is `/var/www/html/web`:

```shell
PHP_CODE_METRICS /var/www/html/web/modules/custom
```

### Accessibility with Pa11y

Accessibility tests with [Pa11y](https://pa11y.org/), tests are defined in
[.gitlab-ci/pa11y-ci.json](.gitlab-ci/pa11y-ci.json)

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

As per Drupal 8 good practices it is not meant to deploy any database,
only the codebase.

This project include a sample assuming you can ssh to a remote host.  
From this starting point, you can include any script to match your deploy
process.

For some examples, see the documentation: [https://docs.gitlab.com/ee/ci/examples/README.html](https://docs.gitlab.com/ee/ci/examples/README.html)

## Jobs detail

Available stages on the pipelines are:

```shell
- build
- tests
# [TESTING] Next lines can be removed for testing only.
# On each push.
- code quality
- code lint
# Only on tag, when released.
- php code metrics
# [DEPLOY] Skipped by default, see SKIP_DEPLOY in .gitlab-ci-variables.yml
# [DEPLOY] Manual if branch testing or master or tag.
- deploy to testing
# [DEPLOY] Manual if branch master or tag.
- deploy to staging
# [DEPLOY] Manual if branch master or tag.
- deploy to production
```

Available jobs

| Name | Detail | Drupal install | Report  |
|---|---|---|:---:|
| Build | If a project : `composer install`, can be used to add build steps (composer run-script, grunt, webpack, yarn...) | No | No |
| Unit and kernel | Phpunit unit and kernel tests | No | xml and html |
| Code coverage | Phpunit unit and kernel tests generating coverage, Codecov.io support see [Codecov.io support](#codecovio-support) | No | xml and html |
| Functional | Phpunit functional test (Browser based tests) | No | xml and html |
| Functional Js | Phpunit functional javascript test (Browser with javascript based tests) | Yes (included) | xml and html |
| Nightwatch Js | Nightwatch.js javascript test (Browser with javascript based tests), see [Nightwatch.js for Drupal 8](#nightwatchjs-for-drupal-8) | Yes (included) | text and html |
| Security report | Symfony security-checker, look at versions in composer.lock | No | text |
| Behat tests | Support Behat tests from `tests` folder, see [Behat tests for Drupal 8](#behat-tests-for-drupal-8) | Yes | html |
| Pa11y | Accessibility tests with [Pa11y](https://pa11y.org/), tests are defined in [.gitlab-ci/pa11y-ci.json](.gitlab-ci/pa11y-ci.json) | Yes | text |
| Code quality | Code sniffer with _Drupal standards_ | No | html |
| Best practices | Code sniffer with _Drupal Best practices standard_ | No | html |
| Js lint | Javascript check with eslint (as used in Drupal core, with Drupal rules) | No | html |
| Css lint | Css check with stylelint (as used in Drupal core, with Drupal rules) | No | text |
| Sass lint | Sass check with sass-lint | No | html |
| Php metrics | Code metrics in a nice html report with phpmetrics | No | html |
| Php stats | Code stats with phploc, pdepend | No | html |
| Deploy to... | Sample of deploy jobs with ssh to a host | No | No |

## CI image including tools

All tools are included in a specific [docker image](https://gitlab.com/mog33/drupal8ci).

Nothing could be done without a bunch of awesome humans building awesome tools.

- [Robo](https://robo.li)
- [Eslint](https://eslint.org/)
- [Sass-lint](https://github.com/sasstools/sass-lint)
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

## Issues

- None currently!

## Future plan

You want to help me make this better? Good! just PR!

I would like to:

- Add Nightwatch [visual regression testing](https://github.com/Crunch-io/nightwatch-vrt)

- Add a matrix option like Travis to test against multiple Php versions and
databases when [Gitlab-Ci support it](https://gitlab.com/gitlab-org/gitlab/issues/23405)

- Test if all of this is working with some distributions like Lightning or
Varbase...

- Have a better and nice local tests solution (WIP).

## Credits

A lot of help and inspiration from those wonderful projects:

- [https://github.com/AcroMedia/commerce-demo](https://github.com/AcroMedia/commerce-demo)
- [https://github.com/Lullabot/drupal8ci](https://github.com/Lullabot/drupal8ci)
- [https://gitlab.com/Lullabot/d8cidemo/tree/gitlab](https://gitlab.com/Lullabot/d8cidemo/tree/gitlab)
- [https://github.com/manumilou/gitlab-ci-example-drupal](https://github.com/manumilou/gitlab-ci-example-drupal)
- [https://bitbucket.org/mediacurrent/ci-tests](https://bitbucket.org/mediacurrent/ci-tests)

----

Want some help implementing this on your project? I provide Drupal 8 expertise
as a freelance, just [contact me](https://developpeur-drupal.com/en).
