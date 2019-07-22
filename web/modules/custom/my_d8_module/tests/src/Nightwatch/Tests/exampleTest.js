module.exports = {
  '@tags': ['custom'],
  before: function(browser) {
    // Profile support on Drupal with patch
    // https://www.drupal.org/node/3017176
    browser
      .drupalInstall({
        setupFile: 'core/tests/Drupal/TestSite/TestSiteInstallTestScript.php',
        installProfile: 'standard',
      });
  },
  after: function(browser) {
    browser
      .drupalUninstall();
  },
  'Example demo test': (browser) => {
    browser
      .drupalRelativeURL('/')
      .waitForElementVisible('body', 1000)
      // Let take a screenshot here for demo.
      .saveScreenshot(`${browser.screenshotsPath}/Desktop_There_is_no_place_like_home.jpg`)
      .assert.containsText('body', 'Welcome to Drupal')
      .assert.title('Welcome to Drupal | Drupal')
      // Screenshot mobile.
      .resizeWindow(375, 812)
      .saveScreenshot(`${browser.screenshotsPath}/Mobile_There_is_no_place_like_home.jpg`)
      // Screenshot tablet.
      .resizeWindow(768, 1280)
      .saveScreenshot(`${browser.screenshotsPath}/Tablet_There_is_no_place_like_home.jpg`)
      .end();
  },
};
