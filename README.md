# Gitlab CI with Drupal

[![pipeline status](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/master) [![coverage report](https://gitlab.com/mog33/gitlab-ci-drupal/badges/testing/coverage.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/testing)

Gitlab CI example for a Drupal 8 project. Include Build, Unit testing, Code
quality, metrics and deploy.

A lot of help and inspiration from those wonderful projects:

- [https://github.com/AcroMedia/commerce-demo](https://github.com/AcroMedia/commerce-demo)
- [https://github.com/Lullabot/drupal8ci](https://github.com/Lullabot/drupal8ci)
- [https://gitlab.com/Lullabot/d8cidemo/tree/gitlab](https://gitlab.com/Lullabot/d8cidemo/tree/gitlab)
- [https://github.com/manumilou/gitlab-ci-example-drupal](https://github.com/manumilou/gitlab-ci-example-drupal)

## Prerequisites

- Gitlab CI with a [runner that support docker](https://docs.gitlab.com/runner/)
- Minimal understanding of [Gitlab CI](https://about.gitlab.com/features/gitlab-ci-cd/) and [Gitlab CI Yaml](https://docs.gitlab.com/ee/ci/yaml)

## Quick how to

Copy those files in the root of your Drupal project (same level as _web/_ folder):

- Folder .gitlab-ci
- .eslintignore
- .phpmd.xml
- .phpqa.yml
- .sass-lint.yml
- .stylelintrc.json
- gitlab-ci.yml
- RoboFile.php

Put some code in you Drupal _modules/custom_ and _themes/custom_ folders.

Run a pipeline from Gitlab UI or push to master!

## Usage

**Note**: The _.gitlab-ci.yml_ file is a bit big, this is meant to be a starting
point for working jobs with Drupal 8, feel free to cherry pick what you need but
be careful about dependencies between some jobs.

If your commit message contains **[ci skip]** or **[skip ci]**, using any
capitalization, the commit will be created but the pipeline will be skipped.

### Drupal 8 code

There is currently 2 ways to use this Gitlab-ci sample, there is some tags in the
_gitlab-ci.yml_ for sections to edit.

For any scenario you need to configure / adapt or delete the deploy part, search
_[DEPLOY]_ sections in _gitlab-ci.yml_.

#### (Default) No composer.json file and base project is Drupal composer template

You are using this project side of your custom modules / themes **WITHOUT** a
composer.json file for Drupal. Then the ci process will install
[Drupal composer template project](https://github.com/drupal-composer/drupal-project)
for you.

This is a good way to only test your custom code.

- Push something to master and on a testing branch, check the CI pipeline!

#### Included composer.json file for your project

You are using this project side of your custom modules / themes / profile
**WITH** a composer.json file, preferably based on[Drupal composer template project](https://github.com/drupal-composer/drupal-project)
but can work with other distributions.

- You need to switch the CI action that manage the installation of Drupal search
  _[COMPOSER.JSON]_ sections.
- Optional: Set properly _WEB_ROOT_ if not ./web/

### Rules

To adapt Code sniffer and Php Mess detector for a Drupal project, use the
_.phpqa.yml_ and _.phpmd.xml_ files with _.gitlab-ci.yml_.

More options see:

- [Phpqa configuration](https://github.com/EdgedesignCZ/phpqa#advanced-configuration---phpqayml)
- [Phpqa .phpqa.yml](https://github.com/EdgedesignCZ/phpqa/blob/master/.phpqa.yml)

Eslint is based on the official [Drupal 8 eslintrc.passing.json](https://cgit.drupalcode.org/drupal/tree/core/.eslintrc.passing.json)

Stylelint is based on the official [Drupal 8 stylelintrc.json](https://cgit.drupalcode.org/drupal/tree/core/.stylelintrc.json)

[Sass-lint](./.sass-lint.yml) is based on [Wolox](https://github.com/Wolox/frontend-bootstrap/blob/master/.sass-lint.yml)

### Rules

This pipeline support Unit, Kernel, Functional, [Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial)
tests in Drupal 8, see [Type of tests in Drupal 8](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

For Drupal 8.6+ [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch)
is working.

## Workflow

Sample workflow used in this file, based on Git branches or tags.
Adapt _only_ and _except_ for your own workflow, see
[Gitlab documentation](https://docs.gitlab.com/ee/ci/yaml/#only-and-except-simplified)

## Tools

All tools are included in a specific [docker image](https://gitlab.com/mog33/drupal8ci).

Nothing could be done without a bunch of awesome humans building awesome tools.

- [Robo](https://robo.li)

Code quality check is done using the wonderful Phpqa, a tool that integrate
other Php tools to analyse your code:

- [Phpqa](https://github.com/EdgedesignCZ/phpqa)
  - [Phploc](https://github.com/sebastianbergmann/phploc)
  - [Phpcpd](https://github.com/sebastianbergmann/phpcpd)
  - [PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer)
  - [Phpmd](https://github.com/phpmd/phpmd)
  - [PHP-Parallel-Lint](https://github.com/JakubOnderka/PHP-Parallel-Lint)
  - [Security-checker](https://github.com/sensiolabs/security-checker)
  - [Pdepend](https://pdepend.org/)
  - [Phpmetrics](https://www.phpmetrics.org)

Other amazing tools are Eslint, Sass lint, Nightwatch.js:

- [Eslint](https://eslint.org/)
- [Sass-lint](https://github.com/sasstools/sass-lint)
- [Stylelint](https://github.com/stylelint/stylelint)
- [Nightwatch.js](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch)

## Openstack

If you have access to openstack you can use the cloud config script in openstack/ to quickly set-up a VM for a Gitlab runner.

Get your runner token on Gitlab (>> Settings >> CI / CD >> Runners settings)

Create the instance on openstack, ssh and run:

```bash
sudo gitlab-runner register -n \
  --executor docker \
  --description "My first runner" \
  --docker-image "docker:stable" \
  --docker-privileged \
  --url https://MY_GITLAB_URL \
  --registration-token YOUR_RUNNER_TOKEN_ON_GITLAB
```

## Testing your jobs

If you have access to a runner, you can run a single job (if don't need a build)

```bash
sudo gitlab-runner exec docker 'code quality'
```

More information on the documentation:

- [Gitlab-runner-exec](https://docs.gitlab.com/runner/commands/#gitlab-runner-exec)

In the same time using the variable __CI_DEBUG_TRACE__ in any job can help you.

## Advanced scenarios

If you want to test your Drupal from an existing config, you have to create a
_./config/sync_ folder with your config and set _SETUP_FROM_CONFIG_ in _.gitlab-ci.yml_.

You can perform most of the tests locally (on *unix) without installing any tool
or Drupal code using _docker-compose.yml_ file in this project, require:

- [Docker engine 18+](https://docs.docker.com/install)
- [Docker compose 1.23+](https://docs.docker.com/compose/install)

```bash
docker-compose up -d
```

Copy the config files from this project:

```bash
test/run-tests-ci-locally.sh cp_to_docker
```

Run the tests within the docker stack:

```bash
docker exec -it ci-drupal /scripts/run-tests-ci-locally.sh
```