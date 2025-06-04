// server.js
require('dotenv').config();
const app = require('./src/app');
const cron = require('node-cron');
const { runDailySummary } = require('./src/jobs/dailySummary.job');

const PORT = process.env.PORT || 3000;

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  
  // Schedule daily summary at midnight (00:00) every day
  // This only runs for businesses that haven't manually closed their day
  cron.schedule('0 0 * * *', async () => {
    console.log('Running scheduled daily summary at midnight');
    await runDailySummary();
  }, {
    timezone: "America/New_York" // Adjust based on your needs
  });
});