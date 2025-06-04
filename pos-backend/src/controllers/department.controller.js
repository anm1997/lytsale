// src/controllers/department.controller.js
const { supabaseAdmin } = require('../config/supabase');

// Get all departments for a business
const getDepartments = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    
    const { data: departments, error } = await supabaseAdmin
      .from('departments')
      .select('*')
      .eq('business_id', businessId)
      .order('name');
    
    if (error) throw error;
    
    res.json({ departments });
  } catch (error) {
    next(error);
  }
};

// Get single department
const getDepartment = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    const { data: department, error } = await supabaseAdmin
      .from('departments')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'Department not found' });
    }
    
    res.json({ department });
  } catch (error) {
    next(error);
  }
};

// Create new department
const createDepartment = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { 
      name, 
      taxable, 
      ageRestriction, 
      timeRestriction 
    } = req.body;
    
    // Check if department name already exists
    const { data: existing } = await supabaseAdmin
      .from('departments')
      .select('id')
      .eq('business_id', businessId)
      .eq('name', name)
      .single();
    
    if (existing) {
      return res.status(400).json({ error: 'Department name already exists' });
    }
    
    const { data: department, error } = await supabaseAdmin
      .from('departments')
      .insert({
        business_id: businessId,
        name,
        taxable: taxable || false,
        age_restriction: ageRestriction || null,
        time_restriction: timeRestriction || null,
        system: false // User-created departments are not system
      })
      .select()
      .single();
    
    if (error) throw error;
    
    res.status(201).json({ 
      message: 'Department created successfully',
      department 
    });
  } catch (error) {
    next(error);
  }
};

// Update department
const updateDepartment = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    const updates = req.body;
    
    // Check if department exists and belongs to business
    const { data: existing } = await supabaseAdmin
      .from('departments')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!existing) {
      return res.status(404).json({ error: 'Department not found' });
    }
    
    // Prevent updating system departments
    if (existing.system) {
      return res.status(400).json({ error: 'Cannot modify system departments' });
    }
    
    // Check if new name conflicts
    if (updates.name && updates.name !== existing.name) {
      const { data: nameConflict } = await supabaseAdmin
        .from('departments')
        .select('id')
        .eq('business_id', businessId)
        .eq('name', updates.name)
        .single();
      
      if (nameConflict) {
        return res.status(400).json({ error: 'Department name already exists' });
      }
    }
    
    const { data: department, error } = await supabaseAdmin
      .from('departments')
      .update({
        name: updates.name || existing.name,
        taxable: updates.taxable !== undefined ? updates.taxable : existing.taxable,
        age_restriction: updates.ageRestriction !== undefined ? updates.ageRestriction : existing.age_restriction,
        time_restriction: updates.timeRestriction !== undefined ? updates.timeRestriction : existing.time_restriction,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw error;
    
    res.json({ 
      message: 'Department updated successfully',
      department 
    });
  } catch (error) {
    next(error);
  }
};

// Delete department
const deleteDepartment = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    // Check if department exists
    const { data: department } = await supabaseAdmin
      .from('departments')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!department) {
      return res.status(404).json({ error: 'Department not found' });
    }
    
    // Prevent deleting system departments
    if (department.system) {
      return res.status(400).json({ error: 'Cannot delete system departments' });
    }
    
    // Check if department has products
    const { data: products } = await supabaseAdmin
      .from('products')
      .select('id')
      .eq('department_id', id)
      .limit(1);
    
    if (products && products.length > 0) {
      return res.status(400).json({ 
        error: 'Cannot delete department with products. Please reassign or delete products first.' 
      });
    }
    
    const { error } = await supabaseAdmin
      .from('departments')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    res.json({ message: 'Department deleted successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getDepartments,
  getDepartment,
  createDepartment,
  updateDepartment,
  deleteDepartment
};