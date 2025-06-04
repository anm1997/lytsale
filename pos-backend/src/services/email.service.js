// src/services/email.service.js
const resend = require('../config/resend');
const { formatCurrency } = require('../utils/formatters');

// Send welcome email (OTP is handled by Supabase automatically)
const sendWelcomeEmail = async (email, businessName) => {
  try {
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL,
      to: email,
      subject: `Welcome to POS System - ${businessName}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #333;">Welcome to POS System!</h1>
          <p>Hi there,</p>
          <p>Thank you for signing up <strong>${businessName}</strong> with our POS system.</p>
          <p>You should receive a verification code in a separate email. Please use it to verify your email address.</p>
          <p>Once verified, you'll need to complete your Stripe Connect setup to start accepting payments.</p>
          <h3>What's next?</h3>
          <ul>
            <li>Verify your email address</li>
            <li>Complete Stripe Connect onboarding</li>
            <li>Set up your departments and products</li>
            <li>Add cashier accounts if needed</li>
          </ul>
          <p>If you have any questions, please don't hesitate to reach out.</p>
          <p>Best regards,<br>POS System Team</p>
        </div>
      `
    });
  } catch (error) {
    console.error('Failed to send welcome email:', error);
    // Don't throw error - email failure shouldn't block signup
  }
};

// Send weekly payout notification
const sendPayoutNotification = async (business, payoutData) => {
  try {
    const { amount, transactionCount, totalFees, dateRange } = payoutData;
    
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL,
      to: business.email,
      subject: `Weekly payout initiated: ${formatCurrency(amount)}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #333;">Weekly Payout Initiated</h2>
          
          <div style="background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #2ecc71; margin-top: 0;">
              ${formatCurrency(amount)} is on its way!
            </h3>
            <p>Expected arrival: 2-3 business days</p>
          </div>
          
          <h3>Summary for ${dateRange}</h3>
          <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
            <p style="margin: 10px 0;">
              <strong>Total Transactions:</strong> ${transactionCount}
            </p>
            <p style="margin: 10px 0;">
              <strong>Gross Sales:</strong> ${formatCurrency(amount + totalFees)}
            </p>
            <p style="margin: 10px 0;">
              <strong>Processing Fees:</strong> -${formatCurrency(totalFees)}
            </p>
            <p style="font-size: 18px; margin: 15px 0; padding-top: 10px; border-top: 1px solid #ddd;">
              <strong>Net Payout:</strong> ${formatCurrency(amount)}
            </p>
          </div>
          
          <p style="margin-top: 20px; color: #666;">
            You can view detailed transaction history in your POS dashboard.
          </p>
          
          <p style="margin-top: 30px;">
            Best regards,<br>
            POS System Team
          </p>
        </div>
      `
    });
  } catch (error) {
    console.error('Failed to send payout notification:', error);
  }
};

// Send daily summary email
const sendDailySummary = async (business, summaryData) => {
  try {
    const {
      date,
      totalSales,
      totalRefunds,
      netSales,
      cashSales,
      cardSales,
      totalTransactions,
      totalFees,
      netAmount,
      topProducts,
      hourlyBreakdown
    } = summaryData;
    
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL,
      to: business.email,
      subject: `Daily Summary for ${new Date(date).toLocaleDateString()}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #333;">Daily Summary - ${business.name}</h2>
          <p style="color: #666;">${new Date(date).toLocaleDateString('en-US', { 
            weekday: 'long', 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
          })}</p>
          
          <div style="background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #2ecc71; margin-top: 0;">
              Net Sales: ${formatCurrency(netSales)}
            </h3>
            <p style="margin: 5px 0;">Total Transactions: ${totalTransactions}</p>
          </div>
          
          <h3>Sales Breakdown</h3>
          <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
            <p style="margin: 10px 0;">
              <strong>Gross Sales:</strong> ${formatCurrency(totalSales)}
            </p>
            <p style="margin: 10px 0;">
              <strong>Refunds:</strong> -${formatCurrency(totalRefunds)}
            </p>
            <hr style="border: none; border-top: 1px solid #ddd; margin: 15px 0;">
            <p style="margin: 10px 0;">
              <strong>Cash Sales:</strong> ${formatCurrency(cashSales)}
            </p>
            <p style="margin: 10px 0;">
              <strong>Card Sales:</strong> ${formatCurrency(cardSales)}
            </p>
          </div>
          
          ${cardSales > 0 ? `
          <h3>Processing Fees</h3>
          <div style="background: #fff5f5; padding: 20px; border-radius: 8px;">
            <p style="margin: 10px 0;">
              <strong>Card Sales:</strong> ${formatCurrency(cardSales)}
            </p>
            <p style="margin: 10px 0; color: #dc3545;">
              <strong>Processing Fees (2.9% + 10¢):</strong> -${formatCurrency(totalFees)}
            </p>
            <hr style="border: none; border-top: 1px solid #ddd; margin: 15px 0;">
            <p style="font-size: 18px; margin: 10px 0;">
              <strong>You'll Receive:</strong> ${formatCurrency(netAmount)}
            </p>
          </div>
          ` : ''}
          
          ${topProducts && topProducts.length > 0 ? `
          <h3>Top Products Today</h3>
          <ol style="margin: 0; padding-left: 20px;">
            ${topProducts.slice(0, 5).map(product => `
              <li style="margin: 5px 0;">
                ${product.name} - ${product.quantity} sold (${formatCurrency(product.revenue)})
              </li>
            `).join('')}
          </ol>
          ` : ''}
          
          <p style="margin-top: 30px; color: #666; font-size: 14px;">
            This is an automated daily summary. Card payments will be included in your weekly payout.
          </p>
        </div>
      `
    });
  } catch (error) {
    console.error('Failed to send daily summary email:', error);
  }
};

module.exports = {
  sendWelcomeEmail,
  sendPayoutNotification,
  sendDailySummary
};