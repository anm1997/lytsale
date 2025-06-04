// src/routes/business.routes.js
const express = require('express');
const router = express.Router();
const businessController = require('../controllers/business.controller');
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

// Business update validation
const businessValidation = [
  body('name')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 }).withMessage('Business name must be between 1 and 100 characters'),
  body('taxRate')
    .optional()
    .isFloat({ min: 0, max: 1 }).withMessage('Tax rate must be between 0 and 1'),
  body('address')
    .optional()
    .isObject().withMessage('Address must be an object'),
  body('settings')
    .optional()
    .isObject().withMessage('Settings must be an object')
];

// All routes require authentication
router.use(authenticate);

// Get business details
router.get('/', businessController.getBusiness);

// Get dashboard stats
router.get('/dashboard', businessController.getDashboard);

// Get settings
router.get('/settings', businessController.getSettings);

// Update business (owner only)
router.put('/',
  authorize('owner'),
  businessValidation,
  validate,
  businessController.updateBusiness
);

// Update settings (owner or manager)
router.put('/settings',
  authorize('owner', 'manager'),
  body('settings').isObject().withMessage('Settings must be an object'),
  validate,
  businessController.updateSettings
);

module.exports = router;