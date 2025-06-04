// src/routes/product.routes.js
const express = require('express');
const router = express.Router();
const productController = require('../controllers/product.controller');
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

// Product validation
const productValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Product name is required')
    .isLength({ max: 100 }).withMessage('Name must be less than 100 characters'),
  body('upc')
    .optional({ nullable: true })
    .trim()
    .isLength({ min: 8, max: 14 }).withMessage('UPC must be between 8 and 14 digits'),
  body('departmentId')
    .notEmpty().withMessage('Department is required')
    .isUUID().withMessage('Invalid department ID'),
  body('price')
    .notEmpty().withMessage('Price is required')
    .isInt({ min: 0 }).withMessage('Price must be positive integer (in cents)'),
  body('caseCost')
    .optional({ nullable: true })
    .isInt({ min: 0 }).withMessage('Case cost must be positive integer (in cents)'),
  body('unitsPerCase')
    .optional({ nullable: true })
    .isInt({ min: 1 }).withMessage('Units per case must be at least 1')
];

// Query validation
const queryValidation = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 }).withMessage('Offset must be non-negative'),
  query('department_id')
    .optional()
    .isUUID().withMessage('Invalid department ID'),
  query('search')
    .optional()
    .trim()
    .isLength({ max: 50 }).withMessage('Search term too long')
];

// All routes require authentication
router.use(authenticate);

// Get all products
router.get('/',
  queryValidation,
  validate,
  productController.getProducts
);

// Get product by ID
router.get('/:id',
  param('id').isUUID().withMessage('Invalid product ID'),
  validate,
  productController.getProduct
);

// Get product by UPC
router.get('/upc/:upc',
  param('upc').trim().notEmpty(),
  validate,
  productController.getProductByUPC
);

// Create product (manager or owner)
router.post('/',
  authorize('owner', 'manager'),
  productValidation,
  validate,
  productController.createProduct
);

// Bulk import products (manager or owner)
router.post('/bulk-import',
  authorize('owner', 'manager'),
  body('products').isArray().withMessage('Products must be an array'),
  validate,
  productController.bulkImportProducts
);

// Update product (manager or owner)
router.put('/:id',
  authorize('owner', 'manager'),
  param('id').isUUID().withMessage('Invalid product ID'),
  productValidation,
  validate,
  productController.updateProduct
);

// Delete product (owner only)
router.delete('/:id',
  authorize('owner'),
  param('id').isUUID().withMessage('Invalid product ID'),
  validate,
  productController.deleteProduct
);

module.exports = router;