# Local testing simulating Gitlab-CI [WIP]

This is a Docker stack to help run the tests locally using our ci image.

Mainly it's used to reproduce the Gitlab-ci jobs from this project, but it
provide some script to run tests locally quickly.

This is a **WIP** and there is no support on this for now.

## Install

Require at minimum:

```bash
.gitlab-ci/local/_commands.sh
.gitlab-ci/local/ci.sh
.gitlab-ci/local/docker-compose.yml
.gitlab-ci/local/.env.dist
```

Optional settings files:

```bash
.gitlab-ci/local/.gitignore
```

Optional variable override for this script:

```bash
.gitlab-ci/local/local.yml
```

## Ci type module

Edit `.gitlab-ci/local/docker-compose.yml` and uncomment volume for a module:

```yaml
  - ../../:/opt/drupal/web/modules/custom/${CI_PROJECT_NAME}
```

Create a `local.yml` file in this directory:

```yaml
CI_TYPE: module
```

Launch the stack and one time build for ci mimic:

```bash
.gitlab-ci/local/ci.sh up
.gitlab-ci/local/ci.sh build
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

### Nightwatch tests

Default will run the value of `CI_NIGHTWATCH_TESTS`.

```bash
.gitlab-ci/local/ci.sh nightwatch
```

For specific test or value, you can pass options to override `CI_NIGHTWATCH_TESTS`.

```bash
.gitlab-ci/local/ci.sh nightwatch --tag demo
```

If the args contain a path to a js file, it must be relative to `DOC_ROOT/core` path, to have path completion it's better to be in `DOC_ROOT/core`:

```bash
cd web/core
../../.gitlab-ci/local/ci.sh nightwatch ../modules/custom/my_module/tests/src/Nightwatch/Tests/exampleModuleTest.js
``````

### Qa tests

Run qa tests:

```bash
.gitlab-ci/local/ci.sh qa
```

[...]
