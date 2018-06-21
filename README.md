# Gitlab CI with Drupal

Gitlab CI samples for Drupal / Php project, code quality with Phpqa.

## Prerequisites

* Gitlab CI with a runner that support docker https://docs.gitlab.com/runner/
* Minimal understanding of Gitlab CI https://about.gitlab.com/features/gitlab-ci-cd/

## Quick how to

Copy *.yml and phpqa_config/ from this project to your project.

Run a pipeline from Gitlab UI or push to master!

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
