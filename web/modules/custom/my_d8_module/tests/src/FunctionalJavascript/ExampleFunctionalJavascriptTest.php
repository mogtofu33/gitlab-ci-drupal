<?php

namespace Drupal\Tests\my_d8_module\FunctionalJavascript;

use Drupal\FunctionalJavascriptTests\WebDriverTestBase;

/**
 * Tests Functional Javascript.
 *
 * @group action
 */
class ExampleFunctionalJavascriptTest extends WebDriverTestBase {

  /**
   * {@inheritdoc}
   */
  public static $modules = ['node'];

  /**
   * Tests the homepage, no specific js here.
   */
  public function testHomepage() {
    $this->drupalGet('<front>');
    $content = $page->findLink('Log in');
    $this->assertTrue($content->isVisible(), 'Log in link visible.');
  }

}
