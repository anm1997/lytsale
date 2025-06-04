const express = require('express');
const router = express.Router();

const authRoutes = require('./auth.routes');
const businessRoutes = require('./business.routes');
const stripeConnectRoutes = require('./stripeConnect.routes');
const departmentRoutes = require('./department.routes');
const productRoutes = require('./product.routes');
const checkoutRoutes = require('./checkout.routes');
const cashRoutes = require('./cash.routes');
const userRoutes = require('./user.routes');
const reportRoutes = require('./report.routes');
const transactionRoutes = require('./transaction.routes');

// Public routes
router.use('/auth', authRoutes);
router.use('/stripe-connect', stripeConnectRoutes);

// Protected routes (these will use auth middleware internally)
router.use('/business', businessRoutes);
router.use('/departments', departmentRoutes);
router.use('/products', productRoutes);
router.use('/checkout', checkoutRoutes);
router.use('/cash', cashRoutes);
router.use('/users', userRoutes);
router.use('/reports', reportRoutes);
router.use('/transactions', transactionRoutes);

module.exports = router;