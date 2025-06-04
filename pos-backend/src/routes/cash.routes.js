// src/routes/cash.routes.js
const express = require('express');
const router = express.Router();
const cashManagementController = require('../controllers/cashManagement.controller');
const { authenticate, authorize } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Cash count validation
const cashCountValidation = [
  body('cashCounts')
    .isObject().withMessage('Cash counts must be an object')
    .custom((value) => {
      const validDenominations = [
        'pennies', 'nickels', 'dimes', 'quarters',
        'ones', 'twos', 'fives', 'tens', 
        'twenties', 'fifties', 'hundreds'
      ];
      
      for (const key in value) {
        if (!validDenominations.includes(key)) {
          throw new Error(`Invalid denomination: ${key}`);
        }
        if (!Number.isInteger(value[key]) || value[key] < 0) {
          throw new Error(`${key} count must be a non-negative integer`);
        }
      }
      return true;
    })
];

// Pay in/out validation
const payValidation = [
  body('amount')
    .isInt({ min: 1 }).withMessage('Amount must be positive'),
  body('note')
    .optional()
    .trim()
    .isLength({ max: 200 }).withMessage('Note too long')
];

// All routes require authentication
router.use(authenticate);

// Start day/shift
router.post('/start-day',
  cashCountValidation,
  validate,
  cashManagementController.startDay
);

// End day/shift
router.post('/end-day',
  cashCountValidation,
  body('skipEmailSummary')
    .optional()
    .isBoolean(),
  validate,
  cashManagementController.endDay
);

// Pay in (add cash)
router.post('/pay-in',
  payValidation,
  validate,
  cashManagementController.payIn
);

// Pay out (remove cash)
router.post('/pay-out',
  payValidation,
  validate,
  cashManagementController.payOut
);

module.exports = router;