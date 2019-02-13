<?php

namespace Drupal\Tests\my_d8_module\Functional;

use Drupal\Tests\BrowserTestBase;

/**
 * Test Functional description.
 *
 * @group my_d8_module
 */
class ExampleFunctionalTest extends BrowserTestBase {

  /**
   * {@inheritdoc}
   */
  public static $modules = ['node', 'block'];

  /**
   * {@inheritdoc}
   */
  public function setUp() {
    parent::setUp();

    $this->drupalPlaceBlock('page_title_block');
  }

  /**
   * Tests Homepage.
   */
  public function testHomepage() {
    // Test homepage.
    $this->drupalGet('<front>');
    $this->assertSession()->statusCodeEquals(200);

    // Minimal homepage title.
    $this->assertSession()->pageTextContains('Log in');
  }

}
