// src/routes/checkout.routes.js
const express = require('express');
const router = express.Router();
const checkoutController = require('../controllers/checkout.controller');
const { authenticate, authenticateCashier } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Add item validation
const addItemValidation = [
  body('upc')
    .optional()
    .trim()
    .isLength({ min: 8, max: 14 }).withMessage('Invalid UPC format'),
  body('departmentId')
    .optional()
    .isUUID().withMessage('Invalid department ID'),
  body('price')
    .optional()
    .isInt({ min: 0 }).withMessage('Price must be positive'),
  body('quantity')
    .optional()
    .isInt({ min: 1 }).withMessage('Quantity must be at least 1')
];

// Payment validation
const paymentValidation = [
  body('items')
    .isArray({ min: 1 }).withMessage('At least one item required'),
  body('paymentMethod')
    .isIn(['cash', 'card']).withMessage('Invalid payment method'),
  body('subtotal')
    .isInt({ min: 0 }).withMessage('Invalid subtotal'),
  body('taxAmount')
    .isInt({ min: 0 }).withMessage('Invalid tax amount'),
  body('totalAmount')
    .isInt({ min: 1 }).withMessage('Invalid total amount'),
  body('cashReceived')
    .if(body('paymentMethod').equals('cash'))
    .isInt({ min: 0 }).withMessage('Cash received amount required for cash payments'),
  body('customerAgeVerified')
    .optional()
    .isBoolean()
];

// Allow both regular auth and cashier PIN auth
const flexibleAuth = (req, res, next) => {
  // Check for Bearer token first
  if (req.headers.authorization) {
    return authenticate(req, res, next);
  }
  // Otherwise try cashier PIN auth
  return authenticateCashier(req, res, next);
};

// Routes
router.post('/start', flexibleAuth, checkoutController.startCheckout);

router.post('/add-item',
  flexibleAuth,
  addItemValidation,
  validate,
  checkoutController.addItem
);

router.post('/verify-age',
  flexibleAuth,
  body('confirmed').isBoolean(),
  body('customerAge').optional().isInt({ min: 0, max: 120 }),
  validate,
  checkoutController.verifyAge
);

router.post('/payment',
  flexibleAuth,
  paymentValidation,
  validate,
  checkoutController.processPayment
);

router.post('/confirm-card-payment',
  flexibleAuth,
  body('transactionId').isUUID(),
  body('paymentIntentId').notEmpty(),
  validate,
  checkoutController.confirmCardPayment
);

module.exports = router;