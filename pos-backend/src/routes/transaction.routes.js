// src/routes/transaction.routes.js
const express = require('express');
const router = express.Router();
const transactionController = require('../controllers/transaction.controller');
const { authenticate, authorize } = require('../middleware/auth');
const { body, param, query, validationResult } = require('express-validator');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Query validation
const transactionQueryValidation = [
  query('startDate')
    .optional()
    .isISO8601().withMessage('Invalid start date'),
  query('endDate')
    .optional()
    .isISO8601().withMessage('Invalid end date'),
  query('type')
    .optional()
    .isIn(['sale', 'refund', 'void', 'pay_in', 'pay_out']),
  query('paymentMethod')
    .optional()
    .isIn(['cash', 'card']),
  query('cashierId')
    .optional()
    .isUUID(),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 }),
  query('offset')
    .optional()
    .isInt({ min: 0 })
];

// Refund validation
const refundValidation = [
  body('items')
    .optional()
    .isArray().withMessage('Items must be an array'),
  body('items.*.itemId')
    .if(body('items').exists())
    .isUUID().withMessage('Invalid item ID'),
  body('items.*.quantity')
    .if(body('items').exists())
    .isInt({ min: 1 }).withMessage('Quantity must be at least 1'),
  body('reason')
    .optional()
    .trim()
    .isLength({ max: 200 }).withMessage('Reason too long')
];

// Void validation
const voidValidation = [
  body('reason')
    .optional()
    .trim()
    .isLength({ max: 200 }).withMessage('Reason too long')
];

// ID validation
const idValidation = [
  param('id').isUUID().withMessage('Invalid transaction ID')
];

// All routes require authentication
router.use(authenticate);

// Get transactions list
router.get('/',
  transactionQueryValidation,
  validate,
  transactionController.getTransactions
);

// Get single transaction
router.get('/:id',
  idValidation,
  validate,
  transactionController.getTransaction
);

// Get receipt for transaction
router.get('/:id/receipt',
  idValidation,
  validate,
  transactionController.getReceipt
);

// Process refund (manager or owner only)
router.post('/:id/refund',
  authorize('owner', 'manager'),
  idValidation,
  refundValidation,
  validate,
  transactionController.processRefund
);

// Void transaction (manager or owner only)
router.post('/:id/void',
  authorize('owner', 'manager'),
  idValidation,
  voidValidation,
  validate,
  transactionController.voidTransaction
);

module.exports = router;