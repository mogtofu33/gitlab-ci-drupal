# Gitlab CI with Drupal 8

[![pipeline status master](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/master)
[![pipeline status testing](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/testing)

<img src="https://www.drupal.org/sites/all/themes/drupalorg_themes/blueprint/images/logo-d8.svg"  width="120" height="120"> +
<img src="https://about.gitlab.com/images/ci/gitlab-ci-cd-logo_2x.png"  width="120" height="120">

[Gitlab CI](https://docs.gitlab.com/ee/ci/README.html) for a
[Drupal 8](https://www.drupal.org) module / theme or project.

Include **Build**,
**Unit testing**, **Code quality**, **Metrics** and **Deploy** samples.

**Table of contents**

- [Prerequisites](#prerequisites)
- [Quick how to](#quick-how-to)
  - [Use Gitlab CI to test your module](#use-gitlab-ci-to-test-your-module)
  - [Use Gitlab CI to test your Drupal project](#use-gitlab-ci-to-test-your-drupal-project)
- [Basic usage](#basic-usage)
  - [Rules for linting / Code standards / QA](#rules-for-linting--code-standards--qa)
  - [PHPunit tests for Drupal 8](#phpunit-tests-for-drupal-8)
- [Workflow proposed](#workflow-proposed)
  - [Branch master](#branch-master)
  - [Branch testing](#branch-testing)
- [Included tools](#included-tools)
- [Running the jobs locally with Docker](#running-the-jobs-locally-with-docker)
- [Credits](#credits)

## Prerequisites

- Gitlab CI with a [runner that support docker](https://docs.gitlab.com/runner/)
- Minimal understanding of [Gitlab CI](https://about.gitlab.com/features/gitlab-ci-cd/) and [Gitlab CI Yaml](https://docs.gitlab.com/ee/ci/yaml)

## Quick how to

### Use Gitlab CI to test your module

_Note:_ Support only for **Drupal 8** at the moment.

Push your module to a Gitlab with CI and runners enabled.
[Gitlab.com](https://gitlab.com) offer 2,000 CI pipeline minutes/month on free
accounts.

Copy `.gitlab-ci.yml` file and `.gitlab-ci` folder in the root of your Drupal
module or theme.

Edit `.gitlab-ci.yml` file to match the tests you need, mainly:

```yaml
image: mogtofu33/drupal8ci:${DRUPAL_VERSION}-selenium
...
variables:
...
  CI_TYPE: "module"
...
  NIGHTWATCH_TESTS: "--tag my_module"
...
  WEB_ROOT: "/var/www/html"
...
  PHP_CODE: "${WEB_ROOT}/modules/custom"
```

You can remove the `[DEPLOY]` parts and probably the `Security report` job if
you don't have dependencies to other projects in your composer.json.

Create a branch **testing**

Push to **testing** and Check your project pipeline or
[Run a pipeline from Gitlab UI](https://docs.gitlab.com/ee/ci/pipelines.html#manually-executing-pipelines)

If you want to choose when to run the CI, for example on a branch master or on a
tag, adapt the section with:

```yaml
.test_except_only: &test_except_only
  # Build and tests are not for master but only branch testing or tags for release.
  # Limit to branch push, for more options see
  # https://docs.gitlab.com/ee/ci/yaml/#only-and-except-simplified
  except:
    - master
  only:
    - testing
    - tags
```

### Use Gitlab CI to test your full Drupal project

Assuming your project include a `composer.json` file from a Drupal project
template.

Copy `.gitlab-ci.yml` file and `.gitlab-ci` folder in the root of your Drupal
project (same level as `composer.json` file).

Put some code in your Drupal `web/modules/custom` and `web/themes/custom`
folders or use included demo code in `web/`

[Run a pipeline from Gitlab UI](https://docs.gitlab.com/ee/ci/pipelines.html#manually-executing-pipelines)
or push to master!

As an example you can check my project on a Drupal 8 template:
[Drupal 8 project template](https://gitlab.com/mog33/drupal-composer-advanced-template)

## Basic usage

**Note**: The `.gitlab-ci.yml` file is meant to be a starting point for working
jobs with [Drupal 8](https://www.drupal.org), feel free to cherry pick what you
need but be careful about dependencies between some jobs.

If your commit message contains **[ci skip]** or **[skip ci]**, using any
capitalization, the commit will be created but the pipeline will be skipped.

### Rules for linting / Code standards / QA

All rules match mostly a Drupal 8 project.

To adapt some rules, first look at `.phpqa.yml`, `.phpmd.xml` and
`.sass-lint.yml` files with `.gitlab-ci.yml`.

More options see:

- [Phpqa configuration](https://github.com/EdgedesignCZ/phpqa#advanced-configuration---phpqayml)
- [Phpqa .phpqa.yml](https://github.com/EdgedesignCZ/phpqa/blob/master/.phpqa.yml)

Eslint is based on the official
[Drupal 8 eslintrc.passing.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.eslintrc.passing.json)

Stylelint is based on the official
[Drupal 8 stylelintrc.json](https://git.drupalcode.org/project/drupal/raw/HEAD/core/.stylelintrc.json)

[Sass-lint](.gitlab-ci/.sass-lint.yml) is based on
[Wolox](https://github.com/Wolox/frontend-bootstrap/blob/master/.sass-lint.yml)

### PHPunit tests for Drupal 8

The pipeline in this project support Unit, Kernel, Functional,
[Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial)
tests in Drupal 8, see
[Type of tests in Drupal 8](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

For Drupal 8 (since 8.6) [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch)
is working.

## Workflow proposed

Sample workflow used in this file, based on Git branches or tags.

By default a new tag or branch _testing_ trigger the build, unit tests,
security, qa, lint, manual deploy to test.
A branch _master_ trigger qa, lint, manual deploy

You can adapt _only_ and _except_ for your own workflow, see
[Gitlab documentation](https://docs.gitlab.com/ee/ci/yaml/#only-and-except-simplified)

### Branch master

[![pipeline_master](https://gitlab.com/mog33/gitlab-ci-drupal/uploads/d2fdb3c36bb89243d4d763290bfef77c/pipeline_master.png)](https://gitlab.com/mog33/gitlab-ci-drupal/pipelines/47581470)

### Branch testing

[![pipeline_testing](https://gitlab.com/mog33/gitlab-ci-drupal/uploads/612e6445d2e4af2e8235d8515fdada08/pipeline_testing.png)](https://gitlab.com/mog33/gitlab-ci-drupal/pipelines/47487091)

## Included tools

All tools are included in a specific [docker image](https://gitlab.com/mog33/drupal8ci).

Nothing could be done without a bunch of awesome humans building awesome tools.

- [Robo](https://robo.li)
- [Eslint](https://eslint.org/)
- [Sass-lint](https://github.com/sasstools/sass-lint)
- [Stylelint](https://github.com/stylelint/stylelint)
- [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch)
- [PHPunit](https://phpunit.de)

Code quality is done using the wonderful Phpqa, a tool that integrate other Php
quality and analysis tools:

- [Phpqa](https://github.com/EdgedesignCZ/phpqa)
  - [Phploc](https://github.com/sebastianbergmann/phploc)
  - [Phpcpd](https://github.com/sebastianbergmann/phpcpd)
  - [PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer)
  - [Phpmd](https://github.com/phpmd/phpmd)
  - [PHP-Parallel-Lint](https://github.com/JakubOnderka/PHP-Parallel-Lint)
  - [Security-checker](https://github.com/sensiolabs/security-checker)
  - [Pdepend](https://pdepend.org/)
  - [Phpmetrics](https://www.phpmetrics.org)

## Running the jobs locally with Docker

You can perform most of the tests locally (on `*Unix`) without installing any
tool or Drupal code using included [docker-compose.yml](tests/docker-compose.yml)
file in this project, require:

- [Docker engine 18+](https://docs.docker.com/install)
- [Docker compose 1.24+](https://docs.docker.com/compose/install)

Default scenario is to have only your custom code modules / themes in a `/web`
folder, then run:

```bash
docker-compose -f tests/docker-compose.yml up -d
```

If you include your own `composer.json` file for_Drupal_, you must edit the
[docker-compose.yml](tests/docker-compose.yml) to use an image without Drupal
and [.docker-compose.env](tests/.docker-compose.env).

An helper bash script can help you run the tests using docker, this is a copy
of the jobs from the [.gitlab-ci.yml](.gitlab-ci.yml) file.

The script will copy configuration files from this folder and ensure folders to
run the tests properly.

```bash
tests/run-tests-ci-locally.sh all
```

## Credits

A lot of help and inspiration from those wonderful projects:

- [https://github.com/AcroMedia/commerce-demo](https://github.com/AcroMedia/commerce-demo)
- [https://github.com/Lullabot/drupal8ci](https://github.com/Lullabot/drupal8ci)
- [https://gitlab.com/Lullabot/d8cidemo/tree/gitlab](https://gitlab.com/Lullabot/d8cidemo/tree/gitlab)
- [https://github.com/manumilou/gitlab-ci-example-drupal](https://github.com/manumilou/gitlab-ci-example-drupal)

----

Want some help implementing this on your project? I provide Drupal 8 expertise
as a freelance, just [contact me](https://developpeur-drupal.com/en).
