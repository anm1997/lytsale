// src/jobs/dailySummary.job.js
const { supabaseAdmin } = require('../config/supabase');
const emailService = require('../services/email.service');
const reportService = require('../services/reports.service');

// Run daily summary for businesses that haven't closed
const runDailySummary = async () => {
  console.log('Running daily summary job at', new Date().toISOString());
  
  try {
    // Get all businesses that haven't sent daily summary today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const { data: businesses, error } = await supabaseAdmin
      .from('businesses')
      .select('*')
      .or(`last_day_closed_at.is.null,last_day_closed_at.lt.${today.toISOString()}`)
      .eq('stripe_connected', true); // Only businesses that can receive payments
    
    if (error) {
      console.error('Error fetching businesses:', error);
      return;
    }
    
    console.log(`Found ${businesses.length} businesses needing daily summary`);
    
    // Process each business
    for (const business of businesses) {
      try {
        // Check if they had any transactions today
        const { data: transactions } = await supabaseAdmin
          .from('transactions')
          .select('id')
          .eq('business_id', business.id)
          .gte('created_at', today.toISOString())
          .limit(1);
        
        if (!transactions || transactions.length === 0) {
          console.log(`No transactions for ${business.name}, skipping`);
          continue;
        }
        
        // Generate summary data
        const summaryData = await reportService.generateDailySummary(business.id, today);
        
        // Send email
        await emailService.sendDailySummary(business, summaryData);
        
        // Mark as sent
        await supabaseAdmin
          .from('businesses')
          .update({ 
            daily_summary_sent: true,
            last_summary_sent_at: new Date().toISOString()
          })
          .eq('id', business.id);
        
        console.log(`Daily summary sent for ${business.name}`);
      } catch (error) {
        console.error(`Error processing business ${business.id}:`, error);
      }
    }
    
    console.log('Daily summary job completed');
  } catch (error) {
    console.error('Daily summary job failed:', error);
  }
};

module.exports = { runDailySummary };