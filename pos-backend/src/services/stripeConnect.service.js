// src/services/stripeConnect.service.js
const { stripe } = require('../config/stripe');
const { supabaseAdmin } = require('../config/supabase');
const { STRIPE_CONNECT } = require('../config/constants');

// Generate OAuth link for Stripe Connect
const generateOAuthLink = (businessId) => {
  const params = new URLSearchParams({
    client_id: process.env.STRIPE_CLIENT_ID,
    response_type: 'code',
    scope: 'read_write',
    redirect_uri: `${process.env.APP_URL}/api/stripe-connect/callback`,
    state: businessId, // Pass business ID to callback
    stripe_user: {
      email: '{{USER_EMAIL}}', // Will be filled by Stripe
      url: '{{BUSINESS_URL}}',
      country: 'US',
      business_type: 'company'
    }
  });

  return `${STRIPE_CONNECT.OAUTH_URL}?${params.toString()}`;
};

// Complete onboarding by exchanging code for account ID
const completeOnboarding = async (authorizationCode, businessId) => {
  try {
    // Exchange authorization code for access token
    const response = await stripe.oauth.token({
      grant_type: 'authorization_code',
      code: authorizationCode
    });

    const stripeAccountId = response.stripe_user_id;

    // Update business with Stripe account ID
    const { error: updateError } = await supabaseAdmin
      .from('businesses')
      .update({
        stripe_account_id: stripeAccountId,
        stripe_connected: true,
        stripe_connected_at: new Date().toISOString()
      })
      .eq('id', businessId);

    if (updateError) {
      throw new Error('Failed to update business');
    }

    // Set payout schedule to weekly
    await stripe.accounts.update(stripeAccountId, {
      settings: {
        payouts: {
          schedule: {
            interval: 'weekly',
            weekly_anchor: 'monday'
          }
        }
      }
    });

    // Create webhook endpoint for this account
    await createWebhookEndpoint(stripeAccountId);

    return { success: true, accountId: stripeAccountId };
  } catch (error) {
    console.error('Onboarding error:', error);
    return { error: error.message };
  }
};

// Check account status
const checkAccountStatus = async (businessId) => {
  try {
    const { data: business } = await getBusinessStripeStatus(businessId);
    
    if (!business.stripe_account_id) {
      return {
        connected: false,
        ready: false,
        message: 'No Stripe account connected'
      };
    }

    // Get account details from Stripe
    const account = await stripe.accounts.retrieve(business.stripe_account_id);

    return {
      connected: true,
      ready: account.charges_enabled && account.payouts_enabled,
      details_submitted: account.details_submitted,
      charges_enabled: account.charges_enabled,
      payouts_enabled: account.payouts_enabled,
      requirements: account.requirements,
      created: account.created,
      country: account.country,
      default_currency: account.default_currency
    };
  } catch (error) {
    console.error('Status check error:', error);
    return {
      connected: false,
      ready: false,
      error: error.message
    };
  }
};

// Get business Stripe status
const getBusinessStripeStatus = async (businessId) => {
  return await supabaseAdmin
    .from('businesses')
    .select('id, stripe_account_id, stripe_connected')
    .eq('id', businessId)
    .single();
};

// Create account link for additional onboarding
const createAccountLink = async (stripeAccountId, type = 'account_onboarding') => {
  const accountLink = await stripe.accountLinks.create({
    account: stripeAccountId,
    refresh_url: `${process.env.FRONTEND_URL}/settings`,
    return_url: `${process.env.FRONTEND_URL}/settings?stripe=updated`,
    type: type
  });

  return accountLink;
};

// Create login link for Stripe dashboard
const createLoginLink = async (stripeAccountId) => {
  const loginLink = await stripe.accounts.createLoginLink(stripeAccountId);
  return loginLink;
};

// Create webhook endpoint for connected account
const createWebhookEndpoint = async (stripeAccountId) => {
  try {
    // Create webhook for platform events
    const endpoint = await stripe.webhookEndpoints.create({
      url: `${process.env.APP_URL}/webhooks/stripe`,
      enabled_events: [
        'payment_intent.succeeded',
        'payment_intent.payment_failed',
        'charge.refunded',
        'payout.created',
        'payout.paid',
        'payout.failed'
      ],
      connect: true
    });

    console.log('Webhook endpoint created:', endpoint.id);
    return endpoint;
  } catch (error) {
    console.error('Failed to create webhook:', error);
    // Non-critical error - don't fail onboarding
  }
};

module.exports = {
  generateOAuthLink,
  completeOnboarding,
  checkAccountStatus,
  getBusinessStripeStatus,
  createAccountLink,
  createLoginLink
};