/**
 * @file
 * Sample testing.
 */
(($, Drupal) => {
  function init(i, e) {
    const sum = i + 1;
    return sum + e;
  }

  /**
   * Init the JS.
   */
  Drupal.behaviors.testing = {
    attach(context) {
      const $a = $(context).find("a");
      if ($a.length) {
        $a.once("processed").each(init);
      }
    }
  };
})(jQuery, Drupal);
