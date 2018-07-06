# Gitlab CI with Drupal

[![pipeline status](https://gitlab.com/mog33/gitlab-ci-drupal/badges/master/pipeline.svg)](https://gitlab.com/mog33/gitlab-ci-drupal/commits/master)

Gitlab CI samples for a Drupal / Php project. Include Build, Unit testing, Code
quality, metrics and deploy.

A lot of help and inspiration from those wonderful projects:
* https://github.com/AcroMedia/commerce-demo
* https://github.com/Lullabot/drupal8ci
* https://github.com/manumilou/gitlab-ci-example-drupal

## Prerequisites

* Gitlab CI with a runner that support docker https://docs.gitlab.com/runner/
* Minimal understanding of Gitlab CI https://about.gitlab.com/features/gitlab-ci-cd/
* Minimal understanding of Gitlab CI Yaml https://docs.gitlab.com/ee/ci/yaml

## Quick how to

Copy _*.yml_ and _phpqa_config/_, _config/_ from this project to your project.

Put some code in you Drupal _modules/custom_ and _themes/custom_ folders.

Run a pipeline from Gitlab UI or push to master!

## Usage

**Note**: The _.gitlab-ci.yml_ file is way too huge for a normal CI process,
this is just a commented example of working jobs for Drupal 8, feel free to
cherry pick what you need.

If your commit message contains **[ci skip]** or **[skip ci]**, using any
capitalization, the commit will be created but the pipeline will be skipped.

To adapt Code sniffer and Php Mess detector for a Drupal project, use the
_.phpqa.yml_ and _.phpmd.xml_ files with _.gitlab-ci.yml_.

More options see
* https://github.com/EdgedesignCZ/phpqa#advanced-configuration---phpqayml
* https://github.com/EdgedesignCZ/phpqa/blob/master/.phpqa.yml

## Workflow

Sample workflow used in this file, based on Git branches where production is
master. Other branches are testing and staging.

  **X** = include jobs that can stop the pipeline if fail.

  **M** = Manual jobs.

* testing
  * build - **X**
  * test - **X**
  * code quality - **X**
  * code lint
  * deploy to testing
* staging
  * code quality - **X**
  * code lint
  * php code metrics
  * deploy to testing - **X**
  * manual deploy to staging- **M**
* production
  * code quality - **X**
  * code lint
  * php code metrics
  * deploy to testing - **X**
  * manual deploy to staging - **M**
  * manual deploy to production- **M**

## Tools

Nothing could be done without a bunch of awsome humans building awsome tools.

Code quality check is done using the wonderful Phpqa, a tool that integrate
other Php tools to analyse your code:
* https://github.com/EdgedesignCZ/phpqa
  * https://github.com/sebastianbergmann/phploc
  * https://github.com/sebastianbergmann/phpcpd
  * https://github.com/squizlabs/PHP_CodeSniffer
  * https://github.com/pdepend/pdepend
  * https://github.com/phpmd/phpmd
  * https://github.com/JakubOnderka/PHP-Parallel-Lint
  * https://github.com/sensiolabs/security-checker
  * https://phpunit.de

Other amazing tools are Eslint, Sass lint, Markdown lint:
* https://eslint.org/
* https://github.com/sasstools/sass-lint
* https://github.com/markdownlint/markdownlint

We use the fantastic Phpmetrics for some metrics on the project:
* https://www.phpmetrics.org

## Openstack

If you have access to openstack you can use the cloud config script in openstack/ to quickly set-up a VM for a Gitlab runner.

Get your runner token on Gitlab (>> Settings >> CI / CD >> Runners settings)

Create the instance on openstack, ssh and run:

    sudo gitlab-runner register -n \
      --url https://MY_GITLAB_URL \
      --registration-token YOUR_RUNNER_TOKEN_ON_GITLAB \
      --executor docker \
      --description "My first runner" \
      --docker-image "docker:stable" \
      --docker-privileged

## Testing your jobs

If you have access to a runner, you can run a single job

    sudo gitlab-runner exec docker 'code quality'

More information on the documentation:
* https://docs.gitlab.com/runner/commands/#gitlab-runner-exec

In the same time using the variable _CI_DEBUG_TRACE_ in any job can help you.
