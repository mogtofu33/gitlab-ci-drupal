# Local testing simulating Gitlab-CI

This is a Docker stack to help run the tests locally using our ci image.

Mainly it's used to reproduce the Gitlab-ci jobs from this project, but it
provide some script to run tests locally quickly.

This is a **WIP** and there is no support on this for now.

## Install

Require at minimum:

```bash
.gitlab-ci/local/ci.sh
.gitlab-ci/local/docker-compose.yml
.gitlab-ci/local/my.cnf
```

Optional settings files:

```bash
.gitlab-ci/local/.gitignore
.gitlab-ci/.phpqa.yml
.gitlab-ci/.phpmd.xml
.gitlab-ci/phpstan.neon
.gitlab-ci/phpunit.xml
```

Optional variable override for this script:

```bash
.gitlab-ci/local/.local.yml
```

## Ci type module

Edit `.gitlab-ci/local/docker-compose.yml` and uncomment volume for a module:

```yaml
  - ../../:/opt/drupal/web/modules/custom/${CI_PROJECT_NAME}
```

Create a `.local.yml` file in this directory:

```yaml
CI_TYPE: module
# Adapt on conjunction with phpunit.xml in `.gitlab-ci`.
CI_PHPUNIT_TESTS: custom
```

Launch the stack:

```bash
.gitlab-ci/local/ci.sh up
```

### Phpunit tests

Run all PHPUnit on `custom` test:

One time:

```bash
.gitlab-ci/local/ci.sh phpunit
```

Run a unique test:

```bash
.gitlab-ci/local/ci.sh phpunit -d tests/src/Unit/MyTest.php
```

Run your Unit tests:

```bash
.gitlab-ci/local/ci.sh phpunit -d tests/src/Unit
```

Run your Kernel tests:

```bash
.gitlab-ci/local/ci.sh phpunit -d tests/src/Kernel
```

### Qa tests

Run a qa tests:

One time:

```bash
.gitlab-ci/local/ci.sh qa
```

Run a qa single tool test:

One time:

```bash
.gitlab-ci/local/ci.sh qa -qa "phpmd"
.gitlab-ci/local/ci.sh qa -qa "phpqa"
```