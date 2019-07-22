var HtmlReporter = require('nightwatch-html-reporter');
/* Same options as when using the built in nightwatch reporter option */
var reporter = new HtmlReporter({
  openBrowser: false,
  reportsDirectory: '/builds/reports/nightwatch',
  themeName: 'compact'
});

module.exports = {
  write : function(results, options, done) {
    reporter.fn(results, done);
  }
};