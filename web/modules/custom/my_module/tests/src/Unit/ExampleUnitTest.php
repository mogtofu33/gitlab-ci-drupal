<?php

namespace Drupal\Tests\my_module\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\my_module\DemoModuleExampleService;

/**
 * Tests Unit DemoModuleExampleService.
 *
 * @group my_module
 * @coversDefaultClass \Drupal\my_module\DemoModuleExampleService
 */
class ExampleUnitTest extends UnitTestCase {

  protected $dummy;

  /**
   * Before a test method is run, setUp() is invoked.
   * Create new unit object.
   */
  public function setUp() {
    $this->dummy = new DemoModuleExampleService(TRUE);
  }

  /**
   * @covers Drupal\my_module\DemoModuleExampleService::isDummy
   */
  public function testIsDummy() {
    // Dummy test.
    $this->assertEquals($this->dummy->isDummy(), TRUE);
  }

  /**
   * Once test method has finished running, whether it succeeded or failed, tearDown() will be invoked.
   * Unset the $dummy object.
   */
  public function tearDown() {
    unset($this->dummy);
  }

}
