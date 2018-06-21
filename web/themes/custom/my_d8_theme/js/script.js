/**
 * @file
 * Sample testing.
 */
(function ($, Drupal) {
    function init(i, e) {
        console.log('init');
    }

    /**
     * Initialise the JS.
     */
    Drupal.behaviors.testing = {
        attach(context, settings) {
            const $a = $(context).find('a');
            if ($a.length) {
                $a.once('processed').each(init);
            }
        },
    };
}(jQuery, Drupal));