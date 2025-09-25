const nodemailer = require('nodemailer');

async function run() {
  const host = 'smtp-relay.brevo.com';
  const port = 587;
  const user = 'apikey';
  const pass = 'cQp1TIBKtkmCvMH9';
  const from = 'no-reply@alanadiniz.com';
  const to = 'checkcringebank@gmail.com';

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: {
      user,
      pass,
    },
  });

  try {
    const info = await transporter.sendMail({
      to,
      from: {
        address: from,
        name: 'Cringe Bankası',
      },
      subject: 'SMTP connectivity test',
      text: 'Testing Brevo SMTP credentials from Firebase setup.',
    });
    console.log('SMTP test succeeded:', info.messageId);
  } catch (error) {
    console.error('SMTP test failed:', error);
    process.exitCode = 1;
  }
}

run();
