// src/controllers/product.controller.js
const { supabaseAdmin } = require('../config/supabase');

// Get all products for a business
const getProducts = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { department_id, search, limit = 50, offset = 0 } = req.query;
    
    let query = supabaseAdmin
      .from('products')
      .select(`
        *,
        departments (
          id,
          name,
          taxable,
          age_restriction,
          time_restriction
        )
      `)
      .eq('business_id', businessId);
    
    // Filter by department if provided
    if (department_id) {
      query = query.eq('department_id', department_id);
    }
    
    // Search by name or UPC
    if (search) {
      query = query.or(`name.ilike.%${search}%,upc.ilike.%${search}%`);
    }
    
    // Pagination
    query = query
      .range(offset, offset + limit - 1)
      .order('name');
    
    const { data: products, error, count } = await query;
    
    if (error) throw error;
    
    res.json({ 
      products,
      total: count,
      limit,
      offset 
    });
  } catch (error) {
    next(error);
  }
};

// Get single product
const getProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    const { data: product, error } = await supabaseAdmin
      .from('products')
      .select(`
        *,
        departments (
          id,
          name,
          taxable,
          age_restriction,
          time_restriction
        )
      `)
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json({ product });
  } catch (error) {
    next(error);
  }
};

// Get product by UPC
const getProductByUPC = async (req, res, next) => {
  try {
    const { upc } = req.params;
    const businessId = req.user.business_id;
    
    const { data: product, error } = await supabaseAdmin
      .from('products')
      .select(`
        *,
        departments (
          id,
          name,
          taxable,
          age_restriction,
          time_restriction
        )
      `)
      .eq('upc', upc)
      .eq('business_id', businessId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json({ product });
  } catch (error) {
    next(error);
  }
};

// Create product
const createProduct = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const {
      upc,
      name,
      departmentId,
      price,
      caseCost,
      unitsPerCase
    } = req.body;
    
    // Check if UPC already exists for this business
    if (upc) {
      const { data: existing } = await supabaseAdmin
        .from('products')
        .select('id')
        .eq('business_id', businessId)
        .eq('upc', upc)
        .single();
      
      if (existing) {
        return res.status(400).json({ error: 'Product with this UPC already exists' });
      }
    }
    
    // Verify department exists and belongs to business
    const { data: department } = await supabaseAdmin
      .from('departments')
      .select('id')
      .eq('id', departmentId)
      .eq('business_id', businessId)
      .single();
    
    if (!department) {
      return res.status(400).json({ error: 'Invalid department' });
    }
    
    // Calculate margin if case cost provided
    let margin = null;
    if (caseCost && unitsPerCase && price) {
      const unitCost = caseCost / unitsPerCase;
      margin = ((price - unitCost) / price) * 100;
    }
    
    const { data: product, error } = await supabaseAdmin
      .from('products')
      .insert({
        business_id: businessId,
        upc,
        name,
        department_id: departmentId,
        price,
        case_cost: caseCost,
        units_per_case: unitsPerCase,
        margin,
        active: true
      })
      .select(`
        *,
        departments (
          id,
          name,
          taxable,
          age_restriction,
          time_restriction
        )
      `)
      .single();
    
    if (error) throw error;
    
    res.status(201).json({
      message: 'Product created successfully',
      product
    });
  } catch (error) {
    next(error);
  }
};

// Update product
const updateProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    const updates = req.body;
    
    // Check if product exists
    const { data: existing } = await supabaseAdmin
      .from('products')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Check UPC uniqueness if updating
    if (updates.upc && updates.upc !== existing.upc) {
      const { data: upcConflict } = await supabaseAdmin
        .from('products')
        .select('id')
        .eq('business_id', businessId)
        .eq('upc', updates.upc)
        .single();
      
      if (upcConflict) {
        return res.status(400).json({ error: 'Product with this UPC already exists' });
      }
    }
    
    // Verify department if updating
    if (updates.departmentId) {
      const { data: department } = await supabaseAdmin
        .from('departments')
        .select('id')
        .eq('id', updates.departmentId)
        .eq('business_id', businessId)
        .single();
      
      if (!department) {
        return res.status(400).json({ error: 'Invalid department' });
      }
    }
    
    // Calculate new margin if price or cost changed
    let margin = existing.margin;
    const price = updates.price || existing.price;
    const caseCost = updates.caseCost !== undefined ? updates.caseCost : existing.case_cost;
    const unitsPerCase = updates.unitsPerCase || existing.units_per_case;
    
    if (caseCost && unitsPerCase && price) {
      const unitCost = caseCost / unitsPerCase;
      margin = ((price - unitCost) / price) * 100;
    }
    
    const { data: product, error } = await supabaseAdmin
      .from('products')
      .update({
        upc: updates.upc || existing.upc,
        name: updates.name || existing.name,
        department_id: updates.departmentId || existing.department_id,
        price: updates.price || existing.price,
        case_cost: updates.caseCost !== undefined ? updates.caseCost : existing.case_cost,
        units_per_case: updates.unitsPerCase || existing.units_per_case,
        margin,
        active: updates.active !== undefined ? updates.active : existing.active,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select(`
        *,
        departments (
          id,
          name,
          taxable,
          age_restriction,
          time_restriction
        )
      `)
      .single();
    
    if (error) throw error;
    
    res.json({
      message: 'Product updated successfully',
      product
    });
  } catch (error) {
    next(error);
  }
};

// Delete product
const deleteProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    // Check if product exists
    const { data: product } = await supabaseAdmin
      .from('products')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Soft delete by setting active to false
    const { error } = await supabaseAdmin
      .from('products')
      .update({ 
        active: false,
        updated_at: new Date().toISOString()
      })
      .eq('id', id);
    
    if (error) throw error;
    
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    next(error);
  }
};

// Bulk import products
const bulkImportProducts = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { products } = req.body;
    
    if (!Array.isArray(products) || products.length === 0) {
      return res.status(400).json({ error: 'No products provided' });
    }
    
    // Validate and prepare products
    const productsToInsert = [];
    const errors = [];
    
    for (let i = 0; i < products.length; i++) {
      const product = products[i];
      
      // Validate required fields
      if (!product.name || !product.departmentId || !product.price) {
        errors.push(`Row ${i + 1}: Missing required fields`);
        continue;
      }
      
      // Check department exists
      const { data: dept } = await supabaseAdmin
        .from('departments')
        .select('id')
        .eq('id', product.departmentId)
        .eq('business_id', businessId)
        .single();
      
      if (!dept) {
        errors.push(`Row ${i + 1}: Invalid department`);
        continue;
      }
      
      // Calculate margin
      let margin = null;
      if (product.caseCost && product.unitsPerCase && product.price) {
        const unitCost = product.caseCost / product.unitsPerCase;
        margin = ((product.price - unitCost) / product.price) * 100;
      }
      
      productsToInsert.push({
        business_id: businessId,
        upc: product.upc || null,
        name: product.name,
        department_id: product.departmentId,
        price: product.price,
        case_cost: product.caseCost || null,
        units_per_case: product.unitsPerCase || null,
        margin,
        active: true
      });
    }
    
    if (productsToInsert.length === 0) {
      return res.status(400).json({ 
        error: 'No valid products to import',
        errors 
      });
    }
    
    // Insert products
    const { data: inserted, error } = await supabaseAdmin
      .from('products')
      .insert(productsToInsert)
      .select();
    
    if (error) throw error;
    
    res.status(201).json({
      message: `Successfully imported ${inserted.length} products`,
      imported: inserted.length,
      errors: errors.length > 0 ? errors : undefined
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getProducts,
  getProduct,
  getProductByUPC,
  createProduct,
  updateProduct,
  deleteProduct,
  bulkImportProducts
};