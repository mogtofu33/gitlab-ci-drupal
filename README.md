# Gitlab CI with Drupal 8 / 9

<img src="https://www.drupal.org/files/druplicon-small.png" width="175" style="margin-right:10%;">
<img src="https://about.gitlab.com/images/ci/gitlab-ci-cd-logo_2x.png" width="175">

[Gitlab CI](https://docs.gitlab.com/ee/ci/README.html) for a
[Drupal 8 / 9](https://www.drupal.org) module / theme or project.

Include **Build**,
**Unit testing**, **Code quality**, **Metrics** and more...

For any **issue**, please use the [Gitlab-CI project page](https://gitlab.com/mog33/gitlab-ci-drupal/-/issues)

Current branch **3.x-dev** is based on an include behavior, ie you don't have to copy all files from this project.

For legacy (unmaintained) version see branch [8.x-1-dev](https://gitlab.com/mog33/gitlab-ci-drupal/-/tree/8.x-1-dev)

## Prerequisites

- Gitlab CI with a [runner that support docker](https://docs.gitlab.com/runner/)
- Minimal understanding of [Gitlab CI](https://about.gitlab.com/features/gitlab-ci-cd/) and [Gitlab CI Yaml](https://docs.gitlab.com/ee/ci/yaml)

## Documentation

```
Documentation is currently being rewritten and is not yet fully accurate.
```

* https://mog33.gitlab.io/gitlab-ci-drupal

## Quick How TO

### Use with your module / theme / [WIP] profile

Push your module / theme to a Gitlab with CI and runners enabled.

[Gitlab.com](https://gitlab.com) offer 2,000 CI pipeline minutes/month on free
accounts.

- Copy [starter.gitlab-ci.yml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/3.x-dev/starter.gitlab-ci.yml) file as a `.gitlab-ci.yml` at the root of your Drupal module or theme (same level as `my_module_or_theme.info.yml` file).

- If your project is not on [Gitlab.com](https://gitlab.com), edit the `include` section.

- Edit the `variables` and uncomment the section under `Override default variables for a module`

  - **OR** go to Gitlab **Settings > CI/ CD > Variables** and add variables from this section.

- Create and push your branch, see the pipeline running for basic code standard and lint.

External module demo: https://gitlab.com/mog33/demo-gitlab-ci-drupal-module

Drupal 8.9 | Drupal 9.0
:---:|:---:
[![pipeline status master](https://gitlab.com/mog33/demo-gitlab-ci-drupal-module/badges/master/pipeline.svg)](https://gitlab.com/mog33/demo-gitlab-ci-drupal-module/commits/master) | [![pipeline status 9.0](https://gitlab.com/mog33/demo-gitlab-ci-drupal-module/badges/9.0/pipeline.svg)](https://gitlab.com/mog33/demo-gitlab-ci-drupal-module/commits/9.0)

As an example you can check my module:
[Content moderation edit notify](https://gitlab.com/mog33/content_moderation_edit_notify)

### Use with your full Drupal project

Push your project to a Gitlab with CI and runners enabled.

[Gitlab.com](https://gitlab.com) offer 2,000 CI pipeline minutes/month on free
accounts.

Assuming your project include a `composer.json` file from the [Drupal project](https://www.drupal.org/docs/develop/using-composer/using-composer-to-install-drupal-and-manage-dependencies).

- Copy [starter.gitlab-ci.yml](https://gitlab.com/mog33/gitlab-ci-drupal/-/blob/3.x-dev/starter.gitlab-ci.yml) file as a `.gitlab-ci.yml` in your project

- If you are using _Behat_ you must add your tests in a `behat_tests` folders at the root of your Drupal project (same level as `composer.json` file).

  As a starting point you can look in the `behat_tests` folder of this project.

- Put your custom code in the `web/modules/custom` and `web/themes/custom` folders of your project.

- Create and push your branch, see the pipeline running for basic code standard and lint.

To test against another Drupal version, you can edit `.gitlab-ci.yml` **OR** go to Gitlab **Settings > CI/ CD > Variables** and add variable:

Name | Value | Detail
-|-|-
CI_DRUPAL_VERSION | 8.9 | 9.0 is supported

This variable can be set when you run a pipeline directly from Gitlab UI.

External module demo: https://gitlab.com/mog33/demo-gitlab-ci-drupal-project

Drupal 8.9 | Drupal 9.0
:---:|:---:
[![pipeline status master](https://gitlab.com/mog33/demo-gitlab-ci-drupal-project/badges/master/pipeline.svg)](https://gitlab.com/mog33/demo-gitlab-ci-drupal-project/commits/master) | [![pipeline status 9.0](https://gitlab.com/mog33/demo-gitlab-ci-drupal-project/badges/9.0/pipeline.svg)](https://gitlab.com/mog33/demo-gitlab-ci-drupal-project/commits/9.0)

As an example you can check my project on a Drupal template:
[Drupal project advanced template](https://gitlab.com/mog33/drupal-composer-advanced-template)

----

Want some help implementing this on your project? I provide Drupal expertise
as a freelance, just [contact me](https://developpeur-drupal.com/en).

If you want to support this project, you can

- [<img src="https://www.drupal.org/files/images/buy_me_a_coffee.png">](https://bit.ly/34jPKcE)
- Hire me as a freelance for any Drupal related work
- Promote me to any company looking for any Drupal related work
- Help me with testing / documentation / grammar fixes / use cases
