const express = require('express');
const router = express.Router();
const verifyWebhookSignature = require('../middleware/stripeWebhook');
const webhookController = require('../controllers/webhook.controller');

// Stripe webhooks
router.post(
  '/stripe',
  verifyWebhookSignature,
  webhookController.handleStripeWebhook
);

module.exports = router;