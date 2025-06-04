// src/controllers/business.controller.js
const { supabaseAdmin } = require('../config/supabase');
const stripeConnectService = require('../services/stripeConnect.service');

// Get business details
const getBusiness = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    const { data: business, error } = await supabaseAdmin
      .from('businesses')
      .select('*')
      .eq('id', businessId)
      .single();
    
    if (error) throw error;
    
    // Get Stripe connection status if connected
    let stripeStatus = null;
    if (business.stripe_connected) {
      stripeStatus = await stripeConnectService.checkAccountStatus(businessId);
    }
    
    res.json({ 
      business,
      stripeStatus 
    });
  } catch (error) {
    next(error);
  }
};

// Update business settings
const updateBusiness = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const updates = req.body;
    
    // Allowed fields to update
    const allowedUpdates = {};
    
    if (updates.name) allowedUpdates.name = updates.name;
    if (updates.taxRate !== undefined) {
      // Validate tax rate
      if (updates.taxRate < 0 || updates.taxRate > 1) {
        return res.status(400).json({ 
          error: 'Tax rate must be between 0 and 1' 
        });
      }
      allowedUpdates.tax_rate = updates.taxRate;
    }
    
    if (updates.address) {
      allowedUpdates.address = updates.address;
    }
    
    if (updates.settings) {
      // Merge with existing settings
      const { data: current } = await supabaseAdmin
        .from('businesses')
        .select('settings')
        .eq('id', businessId)
        .single();
      
      allowedUpdates.settings = {
        ...current.settings,
        ...updates.settings
      };
    }
    
    allowedUpdates.updated_at = new Date().toISOString();
    
    const { data: business, error } = await supabaseAdmin
      .from('businesses')
      .update(allowedUpdates)
      .eq('id', businessId)
      .select()
      .single();
    
    if (error) throw error;
    
    res.json({
      message: 'Business updated successfully',
      business
    });
  } catch (error) {
    next(error);
  }
};

// Get business stats/dashboard
const getDashboard = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    // Get today's sales
    const { data: todaySales } = await supabaseAdmin
      .from('transactions')
      .select('total_amount')
      .eq('business_id', businessId)
      .eq('type', 'sale')
      .eq('status', 'completed')
      .gte('created_at', today.toISOString());
    
    // Get active products count
    const { count: productCount } = await supabaseAdmin
      .from('products')
      .select('*', { count: 'exact', head: true })
      .eq('business_id', businessId)
      .eq('active', true);
    
    // Get active users count
    const { count: userCount } = await supabaseAdmin
      .from('users')
      .select('*', { count: 'exact', head: true })
      .eq('business_id', businessId)
      .eq('active', true);
    
    // Get recent transactions
    const { data: recentTransactions } = await supabaseAdmin
      .from('transactions')
      .select(`
        id,
        type,
        total_amount,
        payment_method,
        created_at,
        cashier_name
      `)
      .eq('business_id', businessId)
      .order('created_at', { ascending: false })
      .limit(10);
    
    // Calculate today's total
    const todayTotal = todaySales?.reduce((sum, t) => sum + t.total_amount, 0) || 0;
    
    res.json({
      dashboard: {
        todaySales: todayTotal,
        transactionCount: todaySales?.length || 0,
        productCount,
        userCount,
        recentTransactions
      }
    });
  } catch (error) {
    next(error);
  }
};

// Get business settings
const getSettings = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    const { data: business, error } = await supabaseAdmin
      .from('businesses')
      .select('tax_rate, settings, stripe_connected, created_at')
      .eq('id', businessId)
      .single();
    
    if (error) throw error;
    
    res.json({
      taxRate: business.tax_rate,
      settings: business.settings,
      stripeConnected: business.stripe_connected,
      businessAge: Math.floor((Date.now() - new Date(business.created_at)) / (1000 * 60 * 60 * 24))
    });
  } catch (error) {
    next(error);
  }
};

// Update specific settings
const updateSettings = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { settings } = req.body;
    
    // Get current settings
    const { data: current } = await supabaseAdmin
      .from('businesses')
      .select('settings')
      .eq('id', businessId)
      .single();
    
    // Merge settings
    const updatedSettings = {
      ...current.settings,
      ...settings
    };
    
    const { data: business, error } = await supabaseAdmin
      .from('businesses')
      .update({
        settings: updatedSettings,
        updated_at: new Date().toISOString()
      })
      .eq('id', businessId)
      .select('settings')
      .single();
    
    if (error) throw error;
    
    res.json({
      message: 'Settings updated successfully',
      settings: business.settings
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getBusiness,
  updateBusiness,
  getDashboard,
  getSettings,
  updateSettings
};