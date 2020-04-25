<?php

namespace Drupal\my_module;

/**
 * DemoModuleExampleService service.
 */
class DemoModuleExampleService {

  /**
   * Dummy thing.
   *
   * @var bool
   */
  protected $dummy;

  /**
   * Constructs a DemoModuleExampleService object.
   */
  public function __construct(bool $dummy) {
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
