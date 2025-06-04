// src/routes/stripeConnect.routes.js
const express = require('express');
const router = express.Router();
const stripeConnectController = require('../controllers/stripeConnect.controller');
const { authenticate, authorize } = require('../middleware/auth');

// Start onboarding (protected - owner only)
router.post(
  '/onboard',
  authenticate,
  authorize('owner'),
  stripeConnectController.startOnboarding
);

// OAuth callback from Stripe (public - has state validation)
router.get(
  '/callback',
  stripeConnectController.handleCallback
);

// Check account status (protected)
router.get(
  '/status',
  authenticate,
  authorize('owner', 'manager'),
  stripeConnectController.getAccountStatus
);

// Create account link for additional info (protected - owner only)
router.post(
  '/account-link',
  authenticate,
  authorize('owner'),
  stripeConnectController.createAccountLink
);

// Get Stripe dashboard link (protected - owner only)
router.post(
  '/dashboard-link',
  authenticate,
  authorize('owner'),
  stripeConnectController.getDashboardLink
);

module.exports = router;