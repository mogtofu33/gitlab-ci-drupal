<?php

namespace Drupal\Tests\my_module\Kernel;

use Drupal\block\Entity\Block;
use Drupal\KernelTests\KernelTestBase;
use Drupal\my_module\DemoModuleExampleService;

/**
 * Test Kernel.
 *
 * @group my_module
 * @coversDefaultClass \Drupal\my_module\DemoModuleExampleService
 */
class ExampleKernelTest extends KernelTestBase {

  /**
   * The service under test.
   *
   * @var \Drupal\my_module\DemoModuleExampleService
   */
  protected $myService;

  /**
   * The modules to load to run the test.
   *
   * @var array
   */
  public static $modules = [
    'my_module',
  ];

  /**
   * {@inheritdoc}
   */
  protected function setUp() {
    parent::setUp();

    $this->installConfig(['my_module']);

    $this->myService = new DemoModuleExampleService(TRUE);
  }

  /**
   * @covers ::isDummy
   */
  public function testIsDummy() {
    $this->assertEquals($this->myService->isDummy(), TRUE);
  }
}
