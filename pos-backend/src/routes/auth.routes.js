// src/routes/auth.routes.js
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Signup validation
const signupValidation = [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('businessName').notEmpty().trim(),
  body('businessType').isIn(['retail']).withMessage('Only retail businesses are currently supported'),
  body('taxRate').isFloat({ min: 0, max: 1 }).withMessage('Tax rate must be between 0 and 1')
];

// OTP validation
const otpValidation = [
  body('email').isEmail().normalizeEmail(),
  body('token').notEmpty().isLength({ min: 6, max: 6 })
];

// Login validation
const loginValidation = [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty()
];

// Cashier login validation
const cashierLoginValidation = [
  body('businessId').isUUID(),
  body('pin').notEmpty().isLength({ min: 4, max: 4 }).isNumeric()
];

// Routes
router.post('/signup', signupValidation, validate, authController.signup);
router.post('/verify-otp', otpValidation, validate, authController.verifyOtp);
router.post('/login', loginValidation, validate, authController.login);
router.post('/login-cashier', cashierLoginValidation, validate, authController.loginCashier);
router.post('/logout', authController.logout);
router.post('/resend-otp', body('email').isEmail(), validate, authController.resendOtp);

// Protected route
router.get('/me', authenticate, authController.getCurrentUser);

module.exports = router;