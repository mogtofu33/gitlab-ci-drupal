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
    $session = $this->getSession();
    $assert_session = $this->assertSession();
    $page = $session->getPage();
    $this->drupalGet('<front>');
    $this->createScreenshot('public://screenshot.jpg');
    $this->assertFileExists('public://screenshot.jpg');
  }

}
