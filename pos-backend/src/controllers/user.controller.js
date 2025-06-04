// src/controllers/user.controller.js
const { supabaseAdmin } = require('../config/supabase');
const { USER_ROLES } = require('../config/constants');
const crypto = require('crypto');

// Get all users for business
const getUsers = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { role, active } = req.query;
    
    let query = supabaseAdmin
      .from('users')
      .select('*')
      .eq('business_id', businessId)
      .order('created_at', { ascending: false });
    
    if (role) {
      query = query.eq('role', role);
    }
    
    if (active !== undefined) {
      query = query.eq('active', active === 'true');
    }
    
    const { data: users, error } = await query;
    
    if (error) throw error;
    
    // Remove sensitive data
    const sanitizedUsers = users.map(user => ({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: user.active,
      created_at: user.created_at,
      last_login: user.last_login,
      // Don't send PIN
    }));
    
    res.json({ users: sanitizedUsers });
  } catch (error) {
    next(error);
  }
};

// Get single user
const getUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    const { data: user, error } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Remove PIN from response
    const { pin, ...sanitizedUser } = user;
    
    res.json({ user: sanitizedUser });
  } catch (error) {
    next(error);
  }
};

// Create cashier account
const createCashier = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { name, pin, email } = req.body;
    
    // Validate PIN is 4 digits
    if (!/^\d{4}$/.test(pin)) {
      return res.status(400).json({ 
        error: 'PIN must be exactly 4 digits' 
      });
    }
    
    // Check if PIN is already used in this business
    const { data: existingPin } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('business_id', businessId)
      .eq('pin', pin)
      .single();
    
    if (existingPin) {
      return res.status(400).json({ 
        error: 'PIN already in use. Please choose a different PIN.' 
      });
    }
    
    // Create user record (no Supabase auth account for cashiers)
    const { data: cashier, error } = await supabaseAdmin
      .from('users')
      .insert({
        name,
        email: email || null, // Email optional for cashiers
        pin,
        role: USER_ROLES.CASHIER,
        business_id: businessId,
        active: true,
        // Generate a UUID for cashier even though they don't have auth account
        id: crypto.randomUUID()
      })
      .select()
      .single();
    
    if (error) throw error;
    
    res.status(201).json({
      message: 'Cashier created successfully',
      cashier: {
        id: cashier.id,
        name: cashier.name,
        email: cashier.email,
        role: cashier.role,
        active: cashier.active
      }
    });
  } catch (error) {
    next(error);
  }
};

// Update user
const updateUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    const updates = req.body;
    
    // Get existing user
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!existingUser) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Prevent changing owner role
    if (existingUser.role === USER_ROLES.OWNER && updates.role && updates.role !== USER_ROLES.OWNER) {
      return res.status(400).json({ 
        error: 'Cannot change owner role' 
      });
    }
    
    // Prepare updates
    const allowedUpdates = {};
    
    if (updates.name) allowedUpdates.name = updates.name;
    if (updates.email !== undefined) allowedUpdates.email = updates.email;
    if (updates.active !== undefined) allowedUpdates.active = updates.active;
    
    // Role changes (only for non-owners)
    if (updates.role && existingUser.role !== USER_ROLES.OWNER) {
      allowedUpdates.role = updates.role;
    }
    
    allowedUpdates.updated_at = new Date().toISOString();
    
    const { data: updatedUser, error } = await supabaseAdmin
      .from('users')
      .update(allowedUpdates)
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw error;
    
    res.json({
      message: 'User updated successfully',
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        email: updatedUser.email,
        role: updatedUser.role,
        active: updatedUser.active
      }
    });
  } catch (error) {
    next(error);
  }
};

// Update PIN (cashiers only)
const updatePin = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    const { currentPin, newPin } = req.body;
    
    // Validate new PIN
    if (!/^\d{4}$/.test(newPin)) {
      return res.status(400).json({ 
        error: 'PIN must be exactly 4 digits' 
      });
    }
    
    // Get user
    const { data: user } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Only cashiers have PINs
    if (user.role !== USER_ROLES.CASHIER) {
      return res.status(400).json({ 
        error: 'Only cashiers use PIN authentication' 
      });
    }
    
    // Verify current PIN if user is updating their own
    if (req.user.id === id && user.pin !== currentPin) {
      return res.status(401).json({ error: 'Current PIN is incorrect' });
    }
    
    // Check if new PIN is already used
    const { data: existingPin } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('business_id', businessId)
      .eq('pin', newPin)
      .neq('id', id)
      .single();
    
    if (existingPin) {
      return res.status(400).json({ 
        error: 'PIN already in use. Please choose a different PIN.' 
      });
    }
    
    // Update PIN
    const { error } = await supabaseAdmin
      .from('users')
      .update({ 
        pin: newPin,
        updated_at: new Date().toISOString()
      })
      .eq('id', id);
    
    if (error) throw error;
    
    res.json({ message: 'PIN updated successfully' });
  } catch (error) {
    next(error);
  }
};

// Delete user (deactivate)
const deleteUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    // Get user
    const { data: user } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Prevent deleting owner
    if (user.role === USER_ROLES.OWNER) {
      return res.status(400).json({ 
        error: 'Cannot delete business owner account' 
      });
    }
    
    // Soft delete by deactivating
    const { error } = await supabaseAdmin
      .from('users')
      .update({ 
        active: false,
        updated_at: new Date().toISOString()
      })
      .eq('id', id);
    
    if (error) throw error;
    
    res.json({ message: 'User deactivated successfully' });
  } catch (error) {
    next(error);
  }
};

// Get cashier list for PIN login
const getCashierList = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    
    const { data: cashiers, error } = await supabaseAdmin
      .from('users')
      .select('id, name')
      .eq('business_id', businessId)
      .eq('role', USER_ROLES.CASHIER)
      .eq('active', true)
      .order('name');
    
    if (error) throw error;
    
    res.json({ cashiers });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getUsers,
  getUser,
  createCashier,
  updateUser,
  updatePin,
  deleteUser,
  getCashierList
};