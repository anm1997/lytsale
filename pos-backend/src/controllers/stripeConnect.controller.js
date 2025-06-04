// src/controllers/stripeConnect.controller.js
const stripeConnectService = require('../services/stripeConnect.service');
const { STRIPE_CONNECT } = require('../config/constants');

// Start Stripe Connect onboarding
const startOnboarding = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    // Check if already connected
    const { data: business } = await stripeConnectService.getBusinessStripeStatus(businessId);
    
    if (business.stripe_connected) {
      return res.status(400).json({ 
        error: 'Stripe account already connected' 
      });
    }

    // Generate OAuth link
    const oauthLink = stripeConnectService.generateOAuthLink(businessId);
    
    res.json({
      url: oauthLink,
      message: 'Redirect user to this URL to complete Stripe setup'
    });
  } catch (error) {
    next(error);
  }
};

// Handle OAuth callback from Stripe
const handleCallback = async (req, res, next) => {
  try {
    const { code, state } = req.query;
    
    if (!code) {
      // User denied authorization
      return res.redirect(`${process.env.FRONTEND_URL}/settings?error=stripe_cancelled`);
    }

    // State contains the business ID
    const businessId = state;
    
    // Exchange authorization code for account ID
    const result = await stripeConnectService.completeOnboarding(code, businessId);
    
    if (result.error) {
      return res.redirect(`${process.env.FRONTEND_URL}/settings?error=stripe_failed`);
    }

    // Redirect to success page
    res.redirect(`${process.env.FRONTEND_URL}/settings?stripe=connected`);
  } catch (error) {
    console.error('Stripe callback error:', error);
    res.redirect(`${process.env.FRONTEND_URL}/settings?error=stripe_error`);
  }
};

// Check Stripe account status
const getAccountStatus = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    const status = await stripeConnectService.checkAccountStatus(businessId);
    
    res.json(status);
  } catch (error) {
    next(error);
  }
};

// Create account link for additional onboarding
const createAccountLink = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    const { data: business } = await stripeConnectService.getBusinessStripeStatus(businessId);
    
    if (!business.stripe_account_id) {
      return res.status(400).json({ 
        error: 'No Stripe account found. Please complete initial setup first.' 
      });
    }

    const accountLink = await stripeConnectService.createAccountLink(
      business.stripe_account_id,
      'account_onboarding'
    );
    
    res.json({
      url: accountLink.url,
      expires_at: accountLink.expires_at
    });
  } catch (error) {
    next(error);
  }
};

// Get Stripe dashboard link
const getDashboardLink = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    const { data: business } = await stripeConnectService.getBusinessStripeStatus(businessId);
    
    if (!business.stripe_account_id) {
      return res.status(400).json({ 
        error: 'No Stripe account connected' 
      });
    }

    const loginLink = await stripeConnectService.createLoginLink(business.stripe_account_id);
    
    res.json({
      url: loginLink.url
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  startOnboarding,
  handleCallback,
  getAccountStatus,
  createAccountLink,
  getDashboardLink
};