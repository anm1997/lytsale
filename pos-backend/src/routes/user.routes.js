// src/routes/user.routes.js
const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
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

// Cashier validation
const cashierValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ max: 50 }).withMessage('Name too long'),
  body('pin')
    .notEmpty().withMessage('PIN is required')
    .matches(/^\d{4}$/).withMessage('PIN must be exactly 4 digits'),
  body('email')
    .optional({ nullable: true })
    .isEmail().withMessage('Invalid email format')
];

// PIN update validation
const pinValidation = [
  body('currentPin')
    .if((value, { req }) => req.user.id === req.params.id)
    .notEmpty().withMessage('Current PIN is required')
    .matches(/^\d{4}$/).withMessage('Invalid PIN format'),
  body('newPin')
    .notEmpty().withMessage('New PIN is required')
    .matches(/^\d{4}$/).withMessage('PIN must be exactly 4 digits')
];

// Most routes require authentication
router.use(authenticate);

// Get all users
router.get('/',
  query('role').optional().isIn(['owner', 'manager', 'cashier']),
  query('active').optional().isBoolean(),
  validate,
  userController.getUsers
);

// Get single user
router.get('/:id',
  param('id').isUUID().withMessage('Invalid user ID'),
  validate,
  userController.getUser
);

// Create cashier (manager or owner only)
router.post('/cashier',
  authorize('owner', 'manager'),
  cashierValidation,
  validate,
  userController.createCashier
);

// Update user (manager or owner only)
router.put('/:id',
  authorize('owner', 'manager'),
  param('id').isUUID(),
  body('name').optional().trim().isLength({ max: 50 }),
  body('email').optional({ nullable: true }).isEmail(),
  body('active').optional().isBoolean(),
  body('role').optional().isIn(['manager', 'cashier']),
  validate,
  userController.updateUser
);

// Update PIN (cashier can update own, manager/owner can update any)
router.put('/:id/pin',
  param('id').isUUID(),
  pinValidation,
  validate,
  (req, res, next) => {
    // Check if user is updating their own PIN or has permission
    if (req.user.id === req.params.id || 
        req.user.role === 'owner' || 
        req.user.role === 'manager') {
      next();
    } else {
      res.status(403).json({ error: 'Permission denied' });
    }
  },
  userController.updatePin
);

// Delete user (owner only)
router.delete('/:id',
  authorize('owner'),
  param('id').isUUID(),
  validate,
  userController.deleteUser
);

// Public route - get cashier list for PIN login screen
router.get('/business/:businessId/cashiers',
  param('businessId').isUUID(),
  validate,
  userController.getCashierList
);

module.exports = router;