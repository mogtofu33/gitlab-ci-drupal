<?php

namespace Drupal\my_d8_module;

/**
 * DemoModuleExampleService service.
 */
class DemoModuleExampleService {

  /**
   * Node storage.
   *
   * @var bool
   */
  protected $dummy;

  /**
   * Constructs a DemoModuleExampleService object.
   */
  public function __construct($dummy) {
    $this->dummy = $dummy;
  }

  /**
   * Retrieves the dummy!
   *
   * @return bool
   *   The dummy!
   */
  public function isDummy() {
    return $this->dummy;
  }

}
