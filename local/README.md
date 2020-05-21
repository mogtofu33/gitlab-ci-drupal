# Local testing simulating Gitlab-CI

This is a Docker stack to help run the tests locally to debug Gitlab-CI.

This is a **WIP** and there is no support on this for now.

## Tips

Run a single PHPUnit test:

One time
```bash
local/tests_local.sh test functional
```
Then to run agains a unique test:

```bash
docker exec -it -w /var/www/html -u www-data ci-drupal /var/www/html/vendor/bin/phpunit -c /var/www/html/web/core /var/www/html/web/modules/custom/my-project/tests/src/Functional/MY_TEST.php
```