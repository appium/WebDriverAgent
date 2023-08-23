module.exports = {
  require: ['ts-node/register'],
  forbidOnly: Boolean(process.env.CI)
};
