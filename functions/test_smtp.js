const nodemailer = require('nodemailer');

async function test() {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: Number(process.env.SMTP_PORT || 587) === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASSWORD,
    },
  });

  try {
    const info = await transporter.sendMail({
      to: process.env.SMTP_TEST_TO,
      from: {
        address: process.env.SMTP_FROM_EMAIL,
        name: process.env.SMTP_FROM_NAME || 'Test',
      },
      subject: 'SMTP Test',
      text: 'This is a test email',
    });
    console.log('Sent', info);
  } catch (err) {
    console.error('Failed', err);
  }
}

if (!process.env.SMTP_TEST_TO) {
  console.error('Set SMTP_* environment variables before running.');
  process.exit(1);
}

test();
