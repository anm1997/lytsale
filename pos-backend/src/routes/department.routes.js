// src/routes/department.routes.js
const express = require('express');
const router = express.Router();
const departmentController = require('../controllers/department.controller');
const { authenticate, authorize } = require('../middleware/auth');
const { body, param, validationResult } = require('express-validator');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Department validation rules
const departmentValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Department name is required')
    .isLength({ max: 50 }).withMessage('Name must be less than 50 characters'),
  body('taxable')
    .optional()
    .isBoolean().withMessage('Taxable must be true or false'),
  body('ageRestriction')
    .optional({ nullable: true })
    .isInt({ min: 0, max: 100 }).withMessage('Age restriction must be between 0 and 100'),
  body('timeRestriction')
    .optional({ nullable: true })
    .custom((value) => {
      if (!value) return true;
      // Validate time restriction format
      if (!value.start || !value.end) {
        throw new Error('Time restriction must have start and end times');
      }
      // Could add more validation for time format
      return true;
    })
];

// ID validation
const idValidation = [
  param('id').isUUID().withMessage('Invalid department ID')
];

// All routes require authentication
router.use(authenticate);

// Get all departments
router.get('/', departmentController.getDepartments);

// Get single department
router.get('/:id', 
  idValidation,
  validate,
  departmentController.getDepartment
);

// Create department (manager or owner only)
router.post('/',
  authorize('owner', 'manager'),
  departmentValidation,
  validate,
  departmentController.createDepartment
);

// Update department (manager or owner only)
router.put('/:id',
  authorize('owner', 'manager'),
  idValidation,
  departmentValidation,
  validate,
  departmentController.updateDepartment
);

// Delete department (owner only)
router.delete('/:id',
  authorize('owner'),
  idValidation,
  validate,
  departmentController.deleteDepartment
);

module.exports = router;