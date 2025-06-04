// src/controllers/checkout.controller.js
const { supabaseAdmin } = require('../config/supabase');
const { stripe, calculateApplicationFee } = require('../config/stripe');
const { PAYMENT_METHODS, TRANSACTION_TYPES } = require('../config/constants');

// Start a new checkout session
const startCheckout = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    
    // Create a new checkout session
    const sessionId = `checkout_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    res.json({
      sessionId,
      cashier: req.user.name,
      businessId,
      startedAt: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

// Add item to cart (by UPC or manual entry)
const addItem = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { upc, departmentId, price, quantity = 1 } = req.body;
    
    let product = null;
    let itemDetails = {};
    
    // If UPC provided, look up product
    if (upc) {
      const { data } = await supabaseAdmin
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
        .eq('active', true)
        .single();
      
      if (data) {
        product = data;
        itemDetails = {
          productId: product.id,
          name: product.name,
          price: product.price,
          departmentId: product.department_id,
          department: product.departments,
          taxable: product.departments.taxable,
          ageRestriction: product.departments.age_restriction,
          timeRestriction: product.departments.time_restriction
        };
      } else {
        return res.status(404).json({ error: 'Product not found' });
      }
    } else {
      // Manual entry - must have department and price
      if (!departmentId || !price) {
        return res.status(400).json({ 
          error: 'Department and price required for manual entry' 
        });
      }
      
      // Get department details
      const { data: department } = await supabaseAdmin
        .from('departments')
        .select('*')
        .eq('id', departmentId)
        .eq('business_id', businessId)
        .single();
      
      if (!department) {
        return res.status(400).json({ error: 'Invalid department' });
      }
      
      itemDetails = {
        productId: null,
        name: `${department.name} Item`,
        price: price,
        departmentId: department.id,
        department: department,
        taxable: department.taxable,
        ageRestriction: department.age_restriction,
        timeRestriction: department.time_restriction
      };
    }
    
    // Check time restrictions
    if (itemDetails.timeRestriction) {
      const now = new Date();
      const currentHour = now.getHours();
      const { start, end } = itemDetails.timeRestriction;
      
      // Check if current time is within restricted hours
      let isRestricted = false;
      if (start <= end) {
        // Normal range (e.g., 2 AM to 6 AM)
        isRestricted = currentHour >= start && currentHour < end;
      } else {
        // Overnight range (e.g., 12 AM to 6 AM)
        isRestricted = currentHour >= start || currentHour < end;
      }
      
      if (isRestricted) {
        return res.status(403).json({
          error: 'Time restriction',
          message: `This product cannot be sold between ${start}:00 and ${end}:00`,
          restriction: itemDetails.timeRestriction
        });
      }
    }
    
    // Return item details with tax calculation
    const taxRate = req.user.business.tax_rate || 0;
    const itemTax = itemDetails.taxable ? Math.round(itemDetails.price * taxRate) : 0;
    const totalPrice = itemDetails.price * quantity;
    const totalTax = itemTax * quantity;
    
    res.json({
      item: {
        ...itemDetails,
        quantity,
        itemTax,
        totalPrice,
        totalTax,
        totalWithTax: totalPrice + totalTax
      },
      requiresAgeCheck: !!itemDetails.ageRestriction
    });
  } catch (error) {
    next(error);
  }
};

// Verify age for restricted items
const verifyAge = async (req, res, next) => {
  try {
    const { confirmed, customerAge } = req.body;
    
    if (!confirmed) {
      return res.status(403).json({ 
        error: 'Age verification required',
        message: 'Customer age must be verified for restricted items'
      });
    }
    
    res.json({
      verified: true,
      customerAge,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

// Process payment
const processPayment = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    const {
      items,
      paymentMethod,
      subtotal,
      taxAmount,
      totalAmount,
      cashReceived,
      customerAgeVerified
    } = req.body;
    
    // Validate business has Stripe connected for card payments
    if (paymentMethod === PAYMENT_METHODS.CARD) {
      const { data: business } = await supabaseAdmin
        .from('businesses')
        .select('stripe_account_id, stripe_connected')
        .eq('id', businessId)
        .single();
      
      if (!business.stripe_connected || !business.stripe_account_id) {
        return res.status(400).json({ 
          error: 'Stripe not connected',
          message: 'Business must complete Stripe setup to accept card payments'
        });
      }
    }
    
    // Validate items have required age verification
    const restrictedItems = items.filter(item => item.ageRestriction);
    if (restrictedItems.length > 0 && !customerAgeVerified) {
      return res.status(403).json({
        error: 'Age verification required',
        message: 'Customer age must be verified for restricted items'
      });
    }
    
    // Start transaction
    const { data: transaction, error: transactionError } = await supabaseAdmin
      .from('transactions')
      .insert({
        business_id: businessId,
        cashier_id: cashierId,
        cashier_name: req.user.name,
        type: TRANSACTION_TYPES.SALE,
        payment_method: paymentMethod,
        subtotal: subtotal,
        tax_amount: taxAmount,
        total_amount: totalAmount,
        status: paymentMethod === PAYMENT_METHODS.CASH ? 'completed' : 'pending',
        age_verified: customerAgeVerified || false,
        processing_fee: 0,
        net_amount: totalAmount
      })
      .select()
      .single();
    
    if (transactionError) throw transactionError;
    
    // Insert transaction items
    const transactionItems = items.map(item => ({
      transaction_id: transaction.id,
      product_id: item.productId,
      product_name: item.name,
      department_id: item.departmentId,
      quantity: item.quantity,
      price: item.price,
      tax_amount: item.itemTax * item.quantity,
      total: item.totalWithTax
    }));
    
    const { error: itemsError } = await supabaseAdmin
      .from('transaction_items')
      .insert(transactionItems);
    
    if (itemsError) throw itemsError;
    
    // Process payment based on method
    let paymentResult = {};
    
    if (paymentMethod === PAYMENT_METHODS.CASH) {
      // Cash payment - calculate change
      const change = cashReceived - totalAmount;
      
      if (change < 0) {
        // Rollback transaction
        await supabaseAdmin
          .from('transactions')
          .delete()
          .eq('id', transaction.id);
        
        return res.status(400).json({
          error: 'Insufficient cash',
          message: `Customer needs to pay ${formatCurrency(Math.abs(change))} more`
        });
      }
      
      paymentResult = {
        method: 'cash',
        received: cashReceived,
        change: change,
        status: 'completed'
      };
      
    } else if (paymentMethod === PAYMENT_METHODS.CARD) {
      // Card payment - create Stripe payment intent
      const { data: business } = await supabaseAdmin
        .from('businesses')
        .select('stripe_account_id')
        .eq('id', businessId)
        .single();
      
      try {
        // Calculate application fee
        const applicationFee = calculateApplicationFee(totalAmount);
        
        // Create payment intent
        const paymentIntent = await stripe.paymentIntents.create({
          amount: totalAmount,
          currency: 'usd',
          application_fee_amount: applicationFee,
          metadata: {
            transaction_id: transaction.id,
            business_id: businessId
          },
          transfer_data: {
            destination: business.stripe_account_id
          }
        });
        
        // Update transaction with Stripe details
        await supabaseAdmin
          .from('transactions')
          .update({
            stripe_payment_intent_id: paymentIntent.id,
            processing_fee: applicationFee,
            net_amount: totalAmount - applicationFee
          })
          .eq('id', transaction.id);
        
        paymentResult = {
          method: 'card',
          clientSecret: paymentIntent.client_secret,
          paymentIntentId: paymentIntent.id,
          status: 'requires_payment_method'
        };
        
      } catch (stripeError) {
        // Rollback transaction
        await supabaseAdmin
          .from('transactions')
          .delete()
          .eq('id', transaction.id);
        
        throw stripeError;
      }
    }
    
    res.json({
      transaction: {
        id: transaction.id,
        ...transaction
      },
      payment: paymentResult,
      items: transactionItems
    });
  } catch (error) {
    next(error);
  }
};

// Confirm card payment (after Stripe processing)
const confirmCardPayment = async (req, res, next) => {
  try {
    const { transactionId, paymentIntentId } = req.body;
    
    // Verify transaction exists and matches
    const { data: transaction } = await supabaseAdmin
      .from('transactions')
      .select('*')
      .eq('id', transactionId)
      .eq('stripe_payment_intent_id', paymentIntentId)
      .single();
    
    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    // Get payment intent status from Stripe
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    
    if (paymentIntent.status === 'succeeded') {
      // Update transaction status
      await supabaseAdmin
        .from('transactions')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          stripe_charge_id: paymentIntent.latest_charge
        })
        .eq('id', transactionId);
      
      res.json({
        success: true,
        message: 'Payment completed successfully'
      });
    } else {
      res.status(400).json({
        error: 'Payment not completed',
        status: paymentIntent.status
      });
    }
  } catch (error) {
    next(error);
  }
};

// Helper function
const formatCurrency = (cents) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(cents / 100);
};

module.exports = {
  startCheckout,
  addItem,
  verifyAge,
  processPayment,
  confirmCardPayment
};