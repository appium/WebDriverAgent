'use strict';

const gulp = require('gulp');
const boilerplate = require('@appium/gulp-plugins').boilerplate.use(gulp);
const DEFAULTS = require('@appium/gulp-plugins').boilerplate.DEFAULTS;


boilerplate({
  build: 'appium-webdriveragent',
  files: DEFAULTS.files.concat('index.js'),
  projectRoot: __dirname,
});

gulp.task('install:dependencies', gulp.series('transpile', function installDependencies () {
  // we cannot require `fetchDependencies` at the top level because it has not
  // necessarily been transpiled at that point
  const { checkForDependencies } = require('./build');
  return checkForDependencies();
}));
