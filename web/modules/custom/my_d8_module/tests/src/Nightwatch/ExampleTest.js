module.exports = {
  before: function(browser) {
    browser
      .drupalInstall();
  },
  after: function(browser) {
    browser
      .drupalUninstall();
  },
  'Visit the homepage': (browser) => {
    browser
      .relativeURL('/')
      .waitForElementVisible('body', 1000)
      .assert.containsText('body', 'Log in')
      .end();
  },

};
