// src/controllers/webhook.controller.js
const { stripe } = require('../config/stripe');
const { supabaseAdmin } = require('../config/supabase');
const emailService = require('../services/email.service');

// Handle Stripe webhooks
const handleStripeWebhook = async (req, res) => {
  const event = req.stripeEvent; // Set by webhook middleware

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object);
        break;
      
      case 'payment_intent.payment_failed':
        await handlePaymentFailure(event.data.object);
        break;
      
      case 'charge.refunded':
        await handleRefund(event.data.object);
        break;
      
      case 'payout.created':
        await handlePayoutCreated(event.data.object);
        break;
      
      case 'payout.paid':
        await handlePayoutPaid(event.data.object);
        break;
      
      case 'payout.failed':
        await handlePayoutFailed(event.data.object);
        break;
      
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(400).json({ error: 'Webhook handler failed' });
  }
};

// Handle successful payment
const handlePaymentSuccess = async (paymentIntent) => {
  try {
    // Update transaction status only - no email sent per transaction
    await supabaseAdmin
      .from('transactions')
      .update({ 
        status: 'completed',
        completed_at: new Date().toISOString()
      })
      .eq('stripe_payment_intent_id', paymentIntent.id);
  } catch (error) {
    console.error('Error handling payment success:', error);
  }
};

// Handle failed payment
const handlePaymentFailure = async (paymentIntent) => {
  try {
    await supabaseAdmin
      .from('transactions')
      .update({ 
        status: 'failed',
        error_message: paymentIntent.last_payment_error?.message
      })
      .eq('stripe_payment_intent_id', paymentIntent.id);
  } catch (error) {
    console.error('Error handling payment failure:', error);
  }
};

// Handle refund
const handleRefund = async (charge) => {
  try {
    // Update original transaction
    await supabaseAdmin
      .from('transactions')
      .update({ 
        refunded: true,
        refunded_amount: charge.amount_refunded,
        refunded_at: new Date().toISOString()
      })
      .eq('stripe_charge_id', charge.id);
  } catch (error) {
    console.error('Error handling refund:', error);
  }
};

// Handle payout created
const handlePayoutCreated = async (payout) => {
  try {
    // Get business by Stripe account ID
    const { data: business } = await supabaseAdmin
      .from('businesses')
      .select('*')
      .eq('stripe_account_id', payout.account)
      .single();

    if (!business) return;

    // Get transactions for this payout period
    const startDate = new Date(payout.created * 1000 - 7 * 24 * 60 * 60 * 1000); // 7 days ago
    const endDate = new Date(payout.created * 1000);

    const { data: transactions } = await supabaseAdmin
      .from('transactions')
      .select('total_amount, processing_fee')
      .eq('business_id', business.id)
      .eq('status', 'completed')
      .gte('created_at', startDate.toISOString())
      .lt('created_at', endDate.toISOString());

    const totalAmount = transactions.reduce((sum, t) => sum + t.total_amount, 0);
    const totalFees = transactions.reduce((sum, t) => sum + t.processing_fee, 0);

    // Send payout notification
    await emailService.sendPayoutNotification(business, {
      amount: payout.amount,
      transactionCount: transactions.length,
      totalFees: totalFees,
      dateRange: `${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()}`
    });
  } catch (error) {
    console.error('Error handling payout created:', error);
  }
};

// Handle payout paid
const handlePayoutPaid = async (payout) => {
  console.log('Payout paid:', payout.id, 'Amount:', payout.amount);
  // Could update a payouts table if tracking individual payouts
};

// Handle payout failed
const handlePayoutFailed = async (payout) => {
  console.error('Payout failed:', payout.id, 'Reason:', payout.failure_message);
  // Could send alert email to business owner
};

module.exports = {
  handleStripeWebhook
};