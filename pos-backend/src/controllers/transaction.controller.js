// src/controllers/transaction.controller.js
const { supabaseAdmin } = require('../config/supabase');
const { stripe } = require('../config/stripe');
const { TRANSACTION_TYPES } = require('../config/constants');

// Get transactions with filters
const getTransactions = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { 
      startDate, 
      endDate, 
      type, 
      paymentMethod,
      cashierId,
      limit = 50,
      offset = 0 
    } = req.query;
    
    let query = supabaseAdmin
      .from('transactions')
      .select(`
        *,
        transaction_items (
          *,
          products (
            name,
            upc
          )
        )
      `, { count: 'exact' })
      .eq('business_id', businessId)
      .order('created_at', { ascending: false });
    
    // Apply filters
    if (startDate) {
      query = query.gte('created_at', startDate);
    }
    if (endDate) {
      query = query.lte('created_at', endDate);
    }
    if (type) {
      query = query.eq('type', type);
    }
    if (paymentMethod) {
      query = query.eq('payment_method', paymentMethod);
    }
    if (cashierId) {
      query = query.eq('cashier_id', cashierId);
    }
    
    // Pagination
    query = query.range(offset, offset + limit - 1);
    
    const { data: transactions, error, count } = await query;
    
    if (error) throw error;
    
    res.json({
      transactions,
      total: count,
      limit,
      offset
    });
  } catch (error) {
    next(error);
  }
};

// Get single transaction
const getTransaction = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    const { data: transaction, error } = await supabaseAdmin
      .from('transactions')
      .select(`
        *,
        transaction_items (
          *,
          products (
            name,
            upc
          ),
          departments (
            name
          )
        )
      `)
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    res.json({ transaction });
  } catch (error) {
    next(error);
  }
};

// Get receipt data
const getReceipt = async (req, res, next) => {
  try {
    const { id } = req.params;
    const businessId = req.user.business_id;
    
    // Get transaction with all details
    const { data: transaction, error } = await supabaseAdmin
      .from('transactions')
      .select(`
        *,
        businesses (
          name,
          address,
          tax_rate
        ),
        transaction_items (
          *,
          products (
            name,
            upc
          )
        )
      `)
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    // Format receipt data
    const receipt = {
      business: transaction.businesses,
      transaction: {
        id: transaction.id,
        date: transaction.created_at,
        cashier: transaction.cashier_name,
        type: transaction.type,
        paymentMethod: transaction.payment_method
      },
      items: transaction.transaction_items,
      totals: {
        subtotal: transaction.subtotal,
        tax: transaction.tax_amount,
        total: transaction.total_amount
      },
      refund: transaction.refunded ? {
        amount: transaction.refunded_amount,
        date: transaction.refunded_at
      } : null
    };
    
    res.json({ receipt });
  } catch (error) {
    next(error);
  }
};

// Process refund
const processRefund = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { items, reason } = req.body;
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    
    // Get original transaction
    const { data: originalTransaction, error: fetchError } = await supabaseAdmin
      .from('transactions')
      .select(`
        *,
        transaction_items (*)
      `)
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (fetchError || !originalTransaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    // Validate transaction can be refunded
    if (originalTransaction.type !== TRANSACTION_TYPES.SALE) {
      return res.status(400).json({ error: 'Only sales can be refunded' });
    }
    
    if (originalTransaction.refunded) {
      return res.status(400).json({ error: 'Transaction already refunded' });
    }
    
    // Calculate refund amount
    let refundAmount = 0;
    let refundItems = [];
    
    if (items && items.length > 0) {
      // Partial refund
      for (const item of items) {
        const originalItem = originalTransaction.transaction_items.find(
          i => i.id === item.itemId
        );
        
        if (!originalItem) {
          return res.status(400).json({ error: 'Invalid item for refund' });
        }
        
        if (item.quantity > originalItem.quantity) {
          return res.status(400).json({ error: 'Refund quantity exceeds original' });
        }
        
        const itemRefundAmount = Math.round(
          (originalItem.total / originalItem.quantity) * item.quantity
        );
        
        refundAmount += itemRefundAmount;
        refundItems.push({
          ...originalItem,
          quantity: item.quantity,
          total: itemRefundAmount
        });
      }
    } else {
      // Full refund
      refundAmount = originalTransaction.total_amount;
      refundItems = originalTransaction.transaction_items;
    }
    
    // Create refund transaction
    const { data: refundTransaction, error: refundError } = await supabaseAdmin
      .from('transactions')
      .insert({
        business_id: businessId,
        cashier_id: cashierId,
        cashier_name: req.user.name,
        type: TRANSACTION_TYPES.REFUND,
        payment_method: originalTransaction.payment_method,
        subtotal: -refundAmount,
        tax_amount: 0,
        total_amount: -refundAmount,
        status: 'pending',
        original_transaction_id: id,
        note: reason || 'Customer refund'
      })
      .select()
      .single();
    
    if (refundError) throw refundError;
    
    // Insert refund items
    const refundItemsData = refundItems.map(item => ({
      transaction_id: refundTransaction.id,
      product_id: item.product_id,
      product_name: item.product_name,
      department_id: item.department_id,
      quantity: -item.quantity,
      price: item.price,
      tax_amount: -item.tax_amount,
      total: -item.total
    }));
    
    await supabaseAdmin
      .from('transaction_items')
      .insert(refundItemsData);
    
    // Process refund based on payment method
    if (originalTransaction.payment_method === 'card' && originalTransaction.stripe_charge_id) {
      try {
        // Create Stripe refund
        const refund = await stripe.refunds.create({
          charge: originalTransaction.stripe_charge_id,
          amount: refundAmount,
          reason: 'requested_by_customer',
          metadata: {
            refund_transaction_id: refundTransaction.id,
            original_transaction_id: id
          }
        });
        
        // Update refund transaction with Stripe details
        await supabaseAdmin
          .from('transactions')
          .update({
            status: 'completed',
            stripe_refund_id: refund.id,
            completed_at: new Date().toISOString()
          })
          .eq('id', refundTransaction.id);
        
      } catch (stripeError) {
        // Rollback refund transaction
        await supabaseAdmin
          .from('transactions')
          .delete()
          .eq('id', refundTransaction.id);
        
        throw stripeError;
      }
    } else {
      // Cash refund - mark as completed immediately
      await supabaseAdmin
        .from('transactions')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString()
        })
        .eq('id', refundTransaction.id);
    }
    
    // Update original transaction
    await supabaseAdmin
      .from('transactions')
      .update({
        refunded: true,
        refunded_amount: refundAmount,
        refunded_at: new Date().toISOString()
      })
      .eq('id', id);
    
    res.json({
      message: 'Refund processed successfully',
      refundTransaction,
      refundAmount
    });
  } catch (error) {
    next(error);
  }
};

// Void transaction
const voidTransaction = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const businessId = req.user.business_id;
    
    // Get transaction
    const { data: transaction, error: fetchError } = await supabaseAdmin
      .from('transactions')
      .select('*')
      .eq('id', id)
      .eq('business_id', businessId)
      .single();
    
    if (fetchError || !transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    // Validate transaction can be voided
    if (transaction.status !== 'completed') {
      return res.status(400).json({ error: 'Only completed transactions can be voided' });
    }
    
    if (transaction.voided || transaction.refunded) {
      return res.status(400).json({ error: 'Transaction already voided or refunded' });
    }
    
    // Check if transaction is recent (within 24 hours)
    const transactionAge = Date.now() - new Date(transaction.created_at).getTime();
    const twentyFourHours = 24 * 60 * 60 * 1000;
    
    if (transactionAge > twentyFourHours) {
      return res.status(400).json({ 
        error: 'Transaction too old to void. Please process as refund instead.' 
      });
    }
    
    // Update transaction status
    const { error: updateError } = await supabaseAdmin
      .from('transactions')
      .update({
        voided: true,
        voided_at: new Date().toISOString(),
        voided_by: req.user.id,
        void_reason: reason || 'Transaction voided'
      })
      .eq('id', id);
    
    if (updateError) throw updateError;
    
    res.json({
      message: 'Transaction voided successfully'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTransactions,
  getTransaction,
  getReceipt,
  processRefund,
  voidTransaction
};