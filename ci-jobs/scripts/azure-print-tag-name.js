
const branch = process.env.BUILD_SOURCEBRANCH || '';
console.log(branch.replace(/^refs\/tags\//, '')); // eslint-disable-line no-console