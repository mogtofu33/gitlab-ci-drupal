<?php

namespace Drupal\Tests\my_d8_module\Kernel;

use Drupal\block\Entity\Block;
use Drupal\KernelTests\KernelTestBase;
use Drupal\my_d8_module\DemoModuleExampleService;

/**
 * Test Kernel.
 *
 * @group my_d8_module
 */
class ExampleKernelTest extends KernelTestBase {

  /**
   * The service under test.
   *
   * @var \Drupal\my_d8_module\DemoModuleExampleService
   */
  protected $myService;

  /**
   * The modules to load to run the test.
   *
   * @var array
   */
  public static $modules = [
    'my_d8_module',
  ];

  /**
   * {@inheritdoc}
   */
  protected function setUp() {
    parent::setUp();

    $this->installConfig(['my_d8_module']);

    $this->myService = new DemoModuleExampleService(TRUE);
  }

  /**
   * @covers Drupal\my_d8_module\DemoModuleExampleService::isDummy
   */
  public function testIsDummy() {
    $this->assertEquals($this->myService->isDummy(), TRUE);
  }
}
