### Variables

First look in [.gitlab-ci/ci/variables.yml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/4.x-dev/.gitlab-ci/ci/variables.yml)
and check the variables.
This is all the variables you can override from global settings on Gitlab CI or
when manually running a pipeline.

See section [Advanced usage](/advanced-usage/) for more details on each relation
between variables and jobs.

### Skip pipeline

If your commit message contains **[ci skip]** or **[skip ci]**, using any
capitalization, the commit will be created but the pipeline will be skipped.

Alternatively, one can pass the ci.skip Git push option if using Git 2.10 or newer.

`git push -o ci.skip`

### Skip jobs

You can set variables values on your `.gitlab-ci.yml` or in the Gitlab CI UI
under _Settings > CI/CD > Variables_

With variables you can disable some tests without editing any file, available
skip variables are described in [variables.yml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/4.x-dev/.gitlab-ci/ci/variables.yml)

### Workflow of jobs

Tests (and Build) are by default on each push, check `rules:` to adapt.
See documentation: https://docs.gitlab.com/ee/ci/yaml/#rules

You can add global rules on the workflow in your `.gitlab-ci.yml`, see https://docs.gitlab.com/ee/ci/yaml/#workflowrules