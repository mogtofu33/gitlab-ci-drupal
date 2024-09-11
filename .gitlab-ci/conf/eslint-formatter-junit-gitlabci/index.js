/**
 * Very simple Eslint 8 formatter for GitLab CI Junit tests.
 */

"use strict";

const xmlBuilder = require('xmlbuilder')
const path = require('path')

const {
  CI_WEB_ROOT = '/opt/drupal/web',
  CI_DRUPAL_WEB_ROOT = 'web',
  CI_PROJECT_DIR = '/builds',
} = process.env

// https://eslint.org/docs/v8.x/extend/custom-formatters
function parseFailedCase(testCase, source) {
  const { ruleId, severity, message, line, column } = testCase

  const text = `On line ${line}, column ${column} in ${source}: ${message}`

  return {
    '@classname': ruleId,
    '@name': `${line}:${column} > ${message}`,
    '@file': source.split(path.sep).join('/'),
    failure: {
      '@type': getMessageType(severity),
      '#text': text,
    },
  }
}

function parseSuite(testSuite) {
  let filename = testSuite.filePath

  filename = filename
    .replace(CI_PROJECT_DIR + '/', '')
  filename = filename
    .replace('../../..', '')
    .replace(CI_WEB_ROOT, CI_DRUPAL_WEB_ROOT)

  const suiteName = filename.split(path.sep).join('/')
  const failuresCount = testSuite.errorCount

  const success = {
    '@name': 'eslint.passed',
    '@file': `${filename}`,
  }

  const testCases = failuresCount > 0 ? testSuite.messages.map((testCase) => parseFailedCase(testCase, suiteName)) : success

  return {
    testsuite: {
      '@name': suiteName,
      '@failures': failuresCount,
      '@errors': failuresCount,
      '@tests': failuresCount || '1',
      testcase: testCases,
    },
  }
}

function getMessageType(severity) {
  switch (severity) {
    case 1:
      return "warning";
    case 2:
      return "error";
    default:
      break;
  }
  return "";
}

module.exports = (results) => {
  const xmlRoot = xmlBuilder.create('testsuites', { encoding: 'utf-8' }).att('name', 'eslint.rules')
  const testSuites = results.map((testSuite) => parseSuite(testSuite))

  return testSuites.length > 0 ? xmlRoot.element(testSuites).end({ pretty: true }) : xmlRoot.end({ pretty: true })
}
