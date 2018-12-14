# Gitlab CI with Drupal

[![pipeline status](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/master) [![coverage report](https://gitlab.com/mog33/gitlab-ci-drupal/badges/testing/coverage.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/testing)

Gitlab CI samples for a Drupal / Php project. Include Build, Unit testing, Code
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

Copy _*.yml, *.xml, .eslintignore, RoboFile.php_, _.gitlab-ci/_ to your project.

Put some code in you Drupal _modules/custom_ and _themes/custom_ folders.

Run a pipeline from Gitlab UI or push to master!

## Usage

**Note**: The _.gitlab-ci.yml_ file is a big, this is meant to be an example of
working jobs for Drupal 8, feel free to cherry pick what you need.

If your commit message contains **[ci skip]** or **[skip ci]**, using any
capitalization, the commit will be created but the pipeline will be skipped.

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

This pipeline support Unit, Kernel and Functional [tests in Drupal 8](https://www.drupal.org/docs/8/testing/types-of-tests-in-drupal-8).

[Functional Javascript](https://www.drupal.org/docs/8/phpunit/phpunit-javascript-testing-tutorial) is not currently supported, as Drupal 8.6+ include [Nightwatch](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch) this will be the next step.

## Workflow

Sample workflow used in this file, based on Git branches or tags.
Adapt _only_ and _except_ for your own workflow, see [Gitlab documentation](https://docs.gitlab.com/ee/ci/yaml/#only-and-except-simplified)

## Tools

All tools are included in a specific [docker image](https://gitlab.com/mog33/drupal8ci).

Nothing could be done without a bunch of awsome humans building awsome tools.

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

Other amazing tools are Eslint, Sass lint:

- [Eslint](https://eslint.org/)
- [Sass-lint](https://github.com/sasstools/sass-lint)
- [Stylelint](https://github.com/stylelint/stylelint)

## Openstack

If you have access to openstack you can use the cloud config script in openstack/ to quickly set-up a VM for a Gitlab runner.

Get your runner token on Gitlab (>> Settings >> CI / CD >> Runners settings)

Create the instance on openstack, ssh and run:

```shell
sudo gitlab-runner register -n \
  --executor docker \
  --description "My first runner" \
  --docker-image "docker:stable" \
  --docker-privileged \
  --url https://MY_GITLAB_URL \
  --registration-token YOUR_RUNNER_TOKEN_ON_GITLAB
```

## Testing your jobs

If you have access to a runner, you can run a single job

```shell
sudo gitlab-runner exec docker 'code quality'
```

More information on the documentation:

- [Gitlab-runner-exec](https://docs.gitlab.com/runner/commands/#gitlab-runner-exec)

In the same time using the variable __CI_DEBUG_TRACE__ in any job can help you.

## WIP

Selenium integration for [Nightwatch js tests support](https://www.drupal.org/docs/8/testing/javascript-testing-using-nightwatch)