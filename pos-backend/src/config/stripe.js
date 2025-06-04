const Stripe = require('stripe');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// Application fee configuration
const APPLICATION_FEE = {
  percentage: parseFloat(process.env.STRIPE_APPLICATION_FEE_PERCENT), // 0.002 for 0.2%
  fixed: parseInt(process.env.STRIPE_APPLICATION_FEE_FIXED) // 5 for 5 cents
};

// Calculate application fee for a given amount
const calculateApplicationFee = (amount) => {
  return Math.round(amount * APPLICATION_FEE.percentage) + APPLICATION_FEE.fixed;
};

module.exports = { stripe, calculateApplicationFee, APPLICATION_FEE };