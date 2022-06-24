## Future plan

You want to help me make this better? Good! just PR / MR!

I would like to:

- Add deploy sample
  - [WIP] Docker image
  - [TODO] Kubernetes

- Add release sample
  - [TODO] to Gitlab when https://gitlab.com/gitlab-org/release-cli/-/blob/master/docs/index.md#using-this-tool-in-gitlab-ci
  - [TODO] to Drupal.org for a module

- [TODO] Add a variable for artifacts expire_in value, when this is merged:
https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/1893

- [TODO] Add a matrix option like Travis to test against multiple Php versions and
databases when [Gitlab-Ci support it](https://gitlab.com/gitlab-org/gitlab/issues/23405)

- [TODO] Add Codequality report as:
  - https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportscobertura
  - https://docs.gitlab.com/ee/user/project/merge_requests/code_quality.html
  - https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Jobs/Code-Quality.gitlab-ci.yml

- [TODO] Add Images vulnerability scan:
  - https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/Container-Scanning.gitlab-ci.yml

- [WIP] Have a better and nice local tests solution
