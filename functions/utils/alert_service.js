const { sendSlackAlert } = require('./alerts');

/**
 * Unified alert interface
 * Forwards to Slack alerting
 */
async function sendAlert(severity, title, message, metadata = {}) {
  await sendSlackAlert(severity, title, message, metadata);
}

module.exports = {
  sendAlert,
};
