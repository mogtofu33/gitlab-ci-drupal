<?php

namespace Drupal\my_d8_module\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Routing\TrustedRedirectResponse;
use Symfony\Component\HttpFoundation\Response;
use Drupal\Component\Utility\UrlHelper;

/**
 * Class SimpleForm.
 */
class SimpleForm extends FormBase {

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'simple_testing_form';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {

    $form['text'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Text'),
      '#placeholder' => $this->t('Add your text.'),
      '#maxlength' => 64,
      '#size' => 20,
    ];

    $form['submit'] = [
      '#type' => 'submit',
      '#value' => $this->t('Submit it!'),
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function validateForm(array &$form, FormStateInterface $form_state) {
    parent::validateForm($form, $form_state);
    if ($form_state->getValue('text') == 'fail') {
        $form_state->setErrorByName('text', $this->t('No man can agree.'));
    }
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {

    // Log search for statistics purpose.
    $logger = $this->getLogger('testing');
    $logger->info('Someone dare to write: %text', ['%text' => $form_state->getValue('text')]);

    drupal_set_message($this->t('Your text is @text', ['@text' => $form_state->getValue('text')]));
  }

}
