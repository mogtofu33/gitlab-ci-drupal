## Future plan

You want to help me make this better? Good! just PR / MR!

I would like to:

- Add deploy sample
  - Docker image
  - Kubernetes

- Add release sample
  - to Gitlab when https://gitlab.com/gitlab-org/release-cli/-/blob/master/docs/index.md#using-this-tool-in-gitlab-ci
  - to Drupal.org

- Add a variable for artifacts expire_in value, when this is merged:
https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/1893

- Replace chromedriver with Drupal official image `drupalci/webdriver-chromedriver:production`

- Replace Apache webserver by PHP built in

- Add a matrix option like Travis to test against multiple Php versions and
databases when [Gitlab-Ci support it](https://gitlab.com/gitlab-org/gitlab/issues/23405)

- Add support for SQLite and PgSQL database:
  - https://gitlab.com/drupalspoons/composer-plugin/-/blob/2.9.0/templates/.gitlab-ci.yml#L120

- Add SQLite `:memory:`, see https://www.drupal.org/node/3137842

- Add Codequality report as:
  - https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportscobertura
  - https://docs.gitlab.com/ee/user/project/merge_requests/code_quality.html
  - https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Jobs/Code-Quality.gitlab-ci.yml

- Add Images vulnerability scan:
  - https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/Container-Scanning.gitlab-ci.yml

- Have a better and nice local tests solution (WIP).
