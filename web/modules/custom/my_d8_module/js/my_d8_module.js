/**
 * @file
 * Attaches behaviors for Drupal's dummy js.
 */

((Drupal, drupalSettings) => {
  /**
   * This is a dummy js.
   *
   * @type {Drupal~behavior}
   */
  Drupal.behaviors.dummy = {
    attach(context) {
      // Start by finding something.
      const { path } = drupalSettings;

      // If this is the front page, we have to check for the <front> path as
      // well.
      if (path.isFront) {
        const dummy = jQuery("body", context);
        return `${dummy} front`;
      }
    },
    detach(context, settings, trigger) {
      if (trigger === "unload") {
        return "no_front";
      }
    }
  };
})(Drupal, drupalSettings);
