module.exports = {
  '@tags': ['custom'],
  before: function(browser) {
    browser
      .drupalInstall();
  },
  after: function(browser) {
    browser
      .drupalUninstall();
  },
  'Example test homepage': (browser) => {
    browser
      .relativeURL('/')
      .waitForElementVisible('body', 1000)
      .assert.containsText('body', 'Log in')
      .end();
  },

};
