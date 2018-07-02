/**
 * @file
 * Attaches behaviors for Drupal's dummy js.
 */

(function (Drupal, drupalSettings) {
    /**
     * This is a dummy js.
     *
     * @type {Drupal~behavior}
     */
    Drupal.behaviors.dummy = {
        attach(context) {
            // Start by finding something.
            const path = drupalSettings.path;

            // If this is the front page, we have to check for the <front> path as
            // well.
            if (path.isFront) {
                console.info('front');
            }
        },
        detach(context, settings, trigger) {
            if (trigger === 'unload') {
                console.log('no_front');
            }
        },
    };
}(Drupal, drupalSettings));
