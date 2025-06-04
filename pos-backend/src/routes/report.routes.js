// src/routes/report.routes.js
const express = require('express');
const router = express.Router();
const reportsController = require('../controllers/reports.controller');
const { authenticate, authorize } = require('../middleware/auth');
const { query, param, validationResult } = require('express-validator');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Date validation
const dateValidation = [
  query('date')
    .notEmpty().withMessage('Date is required')
    .isISO8601().withMessage('Invalid date format')
];

const dateRangeValidation = [
  query('startDate')
    .notEmpty().withMessage('Start date is required')
    .isISO8601().withMessage('Invalid start date format'),
  query('endDate')
    .notEmpty().withMessage('End date is required')
    .isISO8601().withMessage('Invalid end date format')
];

// All routes require authentication
router.use(authenticate);

// Daily summary report
router.get('/daily-summary',
  dateValidation,
  validate,
  reportsController.getDailySummary
);

// Shift report
router.get('/shift/:shiftId',
  param('shiftId').isUUID().withMessage('Invalid shift ID'),
  validate,
  reportsController.getShiftReport
);

// Product performance report
router.get('/products',
  dateRangeValidation,
  validate,
  reportsController.getProductReport
);

// Hourly sales report
router.get('/hourly',
  dateValidation,
  validate,
  reportsController.getHourlyReport
);

// Sales summary for date range
router.get('/sales-summary',
  dateRangeValidation,
  query('groupBy')
    .optional()
    .isIn(['day', 'week', 'month']).withMessage('Invalid groupBy value'),
  validate,
  reportsController.getSalesSummary
);

// Export reports (manager/owner only)
router.get('/export',
  authorize('owner', 'manager'),
  query('type')
    .notEmpty().withMessage('Report type is required')
    .isIn(['products', 'daily', 'transactions']).withMessage('Invalid report type'),
  dateRangeValidation,
  validate,
  reportsController.exportReport
);

module.exports = router;