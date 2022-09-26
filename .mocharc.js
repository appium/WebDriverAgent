module.exports = {
  require: ['@babel/register'],
  forbidOnly: Boolean(process.env.CI)
};
