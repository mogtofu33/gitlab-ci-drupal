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
  'Example theme test': (browser) => {
    browser
      .drupalRelativeURL('/')
      .waitForElementVisible('body', 1000)
      .assert.containsText('body', 'Log in')
      .end();
  },
};
