// src/controllers/auth.controller.js
const authService = require('../services/auth.service');
const emailService = require('../services/email.service');
const { supabase } = require('../config/supabase');

// Sign up new business owner
const signup = async (req, res, next) => {
  try {
    const { email, password, businessName, businessType, taxRate } = req.body;

    // Validate business type
    if (businessType !== 'retail') {
      return res.status(400).json({ 
        error: 'Only retail businesses are currently supported' 
      });
    }

    // Create user and business
    const result = await authService.createBusinessAndOwner({
      email,
      password,
      businessName,
      businessType,
      taxRate
    });

    if (result.error) {
      return res.status(400).json({ error: result.error });
    }

    // Send welcome email with OTP
    await emailService.sendWelcomeEmail(email, businessName);

    res.status(201).json({
      message: 'Signup successful. Please check your email for verification code.',
      user: result.user,
      business: result.business,
      session: result.session
    });
  } catch (error) {
    next(error);
  }
};

// Verify OTP
const verifyOtp = async (req, res, next) => {
  try {
    const { email, token } = req.body;

    const { data, error } = await supabase.auth.verifyOtp({
      email,
      token,
      type: 'email'
    });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Update user's email_verified status
    await authService.markEmailVerified(data.user.id);

    res.json({
      message: 'Email verified successfully',
      user: data.user
    });
  } catch (error) {
    next(error);
  }
};

// Login with email/password
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      return res.status(401).json({ error: error.message });
    }

    // Get user details with business info
    const userDetails = await authService.getUserWithBusiness(data.user.id);

    res.json({
      message: 'Login successful',
      user: userDetails,
      session: data.session
    });
  } catch (error) {
    next(error);
  }
};

// Login with PIN (for cashiers)
const loginCashier = async (req, res, next) => {
  try {
    const { businessId, pin } = req.body;

    const result = await authService.authenticateCashier(businessId, pin);

    if (result.error) {
      return res.status(401).json({ error: result.error });
    }

    res.json({
      message: 'Login successful',
      user: result.user
    });
  } catch (error) {
    next(error);
  }
};

// Logout
const logout = async (req, res, next) => {
  try {
    const { error } = await supabase.auth.signOut();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Logout successful' });
  } catch (error) {
    next(error);
  }
};

// Get current user
const getCurrentUser = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const userDetails = await authService.getUserWithBusiness(userId);

    res.json({ user: userDetails });
  } catch (error) {
    next(error);
  }
};

// Resend OTP
const resendOtp = async (req, res, next) => {
  try {
    const { email } = req.body;

    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        shouldCreateUser: false
      }
    });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Verification code sent to your email' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  signup,
  verifyOtp,
  login,
  loginCashier,
  logout,
  getCurrentUser,
  resendOtp
};