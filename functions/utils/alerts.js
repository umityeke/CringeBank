/**
 * Alert Utilities
 * 
 * Slack ve email alert gönderme fonksiyonları.
 * Production monitoring için kritik.
 */

const fetch = require('node-fetch');

const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;

/**
 * Send alert to Slack channel
 * 
 * @param {string} severity - 'CRITICAL' | 'WARNING' | 'INFO'
 * @param {string} title - Alert başlığı
 * @param {string} message - Alert mesajı
 * @param {object} metadata - Ek bilgiler (key-value pairs)
 */
async function sendSlackAlert(severity, title, message, metadata = {}) {
  if (!SLACK_WEBHOOK_URL) {
    console.warn('⚠️  Slack webhook not configured, skipping alert');
    return;
  }

  const color = severity === 'CRITICAL' ? 'danger' : severity === 'WARNING' ? 'warning' : 'good';
  const emoji = severity === 'CRITICAL' ? '🚨' : severity === 'WARNING' ? '⚠️' : 'ℹ️';

  try {
    const response = await fetch(SLACK_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: `${emoji} ${title}`,
        attachments: [
          {
            color,
            text: message,
            fields: Object.entries(metadata).map(([key, value]) => ({
              title: key,
              value: String(value),
              short: true,
            })),
            footer: 'CringeBank Monitoring',
            ts: Math.floor(Date.now() / 1000),
          },
        ],
      }),
    });

    if (!response.ok) {
      console.error(`Slack webhook failed: ${response.statusText}`);
    } else {
      console.log(`✅ Slack alert sent: ${title}`);
    }
  } catch (error) {
    console.error('❌ Failed to send Slack alert:', error);
  }
}

/**
 * Send email alert (requires SendGrid setup)
 * 
 * @param {string} severity - 'CRITICAL' | 'WARNING' | 'INFO'
 * @param {string} title - Email subject
 * @param {string} message - Email body
 * @param {object} details - Detailed information for email
 */
async function sendEmailAlert(severity, title, message, details = {}) {
  // Optional: Implement SendGrid email sending
  // Requires @sendgrid/mail package and SENDGRID_API_KEY env var

  console.log(`📧 Email alert (not implemented): ${title}`);
  console.log(`   Severity: ${severity}`);
  console.log(`   Message: ${message}`);
  console.log(`   Details:`, details);

  // Example implementation:
  /*
  const sgMail = require('@sendgrid/mail');
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  const msg = {
    to: 'alerts@cringebank.com',
    from: 'monitoring@cringebank.com',
    subject: `[${severity}] ${title}`,
    text: message,
    html: `
      <h2>${title}</h2>
      <p>${message}</p>
      <h3>Details:</h3>
      <pre>${JSON.stringify(details, null, 2)}</pre>
    `,
  };

  await sgMail.send(msg);
  */
}

/**
 * Log structured message (for Cloud Logging)
 * 
 * @param {string} severity - 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR' | 'CRITICAL'
 * @param {string} message - Log message
 * @param {object} metadata - Additional structured data
 */
function logStructured(severity, message, metadata = {}) {
  const entry = {
    severity,
    message,
    timestamp: new Date().toISOString(),
    ...metadata,
  };

  console.log(JSON.stringify(entry));
}

module.exports = {
  sendSlackAlert,
  sendEmailAlert,
  logStructured,
};
