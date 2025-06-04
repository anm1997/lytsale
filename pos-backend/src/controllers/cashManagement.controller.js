// src/controllers/cashManagement.controller.js
const { supabaseAdmin } = require('../config/supabase');
const emailService = require('../services/email.service');
const reportService = require('../services/reports.service');

// Start day/shift
const startDay = async (req, res, next) => {
  try {
    const { cashCounts } = req.body; // { pennies: 100, nickels: 40, dimes: 50, etc. }
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    
    // Calculate total starting cash
    const startingCash = calculateTotalCash(cashCounts);
    
    // Create shift record
    const { data: shift, error } = await supabaseAdmin
      .from('shifts')
      .insert({
        business_id: businessId,
        cashier_id: cashierId,
        starting_cash: startingCash,
        starting_cash_counts: cashCounts,
        started_at: new Date().toISOString()
      })
      .select()
      .single();
    
    if (error) throw error;
    
    res.status(201).json({
      message: 'Day started successfully',
      shift,
      startingCash: startingCash
    });
  } catch (error) {
    next(error);
  }
};

// End day/shift
const endDay = async (req, res, next) => {
  try {
    const { cashCounts, skipEmailSummary = false } = req.body;
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    
    // Get active shift
    const { data: shift, error: shiftError } = await supabaseAdmin
      .from('shifts')
      .select('*')
      .eq('business_id', businessId)
      .eq('cashier_id', cashierId)
      .is('ended_at', null)
      .single();
    
    if (shiftError || !shift) {
      return res.status(400).json({ error: 'No active shift found' });
    }
    
    // Calculate ending cash
    const endingCash = calculateTotalCash(cashCounts);
    
    // Get all transactions for this shift
    const { data: transactions } = await supabaseAdmin
      .from('transactions')
      .select('*')
      .eq('business_id', businessId)
      .gte('created_at', shift.started_at)
      .in('type', ['sale', 'refund', 'pay_in', 'pay_out']);
    
    // Calculate expected cash
    const cashTransactions = transactions.filter(t => t.payment_method === 'cash');
    const cashSales = cashTransactions
      .filter(t => t.type === 'sale')
      .reduce((sum, t) => sum + t.total_amount, 0);
    const cashRefunds = cashTransactions
      .filter(t => t.type === 'refund')
      .reduce((sum, t) => sum + t.total_amount, 0);
    const payIns = transactions
      .filter(t => t.type === 'pay_in')
      .reduce((sum, t) => sum + t.total_amount, 0);
    const payOuts = transactions
      .filter(t => t.type === 'pay_out')
      .reduce((sum, t) => sum + t.total_amount, 0);
    
    const expectedCash = shift.starting_cash + cashSales - cashRefunds + payIns - payOuts;
    const cashDifference = endingCash - expectedCash;
    
    // Update shift record
    const { data: updatedShift, error: updateError } = await supabaseAdmin
      .from('shifts')
      .update({
        ended_at: new Date().toISOString(),
        ending_cash: endingCash,
        ending_cash_counts: cashCounts,
        expected_cash: expectedCash,
        cash_difference: cashDifference,
        total_cash_sales: cashSales,
        total_card_sales: transactions
          .filter(t => t.type === 'sale' && t.payment_method === 'card')
          .reduce((sum, t) => sum + t.total_amount, 0),
        total_refunds: cashRefunds,
        pay_ins: payIns,
        pay_outs: payOuts
      })
      .eq('id', shift.id)
      .select()
      .single();
    
    if (updateError) throw updateError;
    
    // Mark day as closed for the business
    await supabaseAdmin
      .from('businesses')
      .update({ 
        last_day_closed_at: new Date().toISOString(),
        daily_summary_sent: !skipEmailSummary // If not skipping, mark as sent
      })
      .eq('id', businessId);
    
    // Send daily summary email if not skipped
    if (!skipEmailSummary) {
      const summaryData = await reportService.generateDailySummary(businessId, new Date());
      await emailService.sendDailySummary(req.user.business, summaryData);
    }
    
    res.json({
      message: 'Day ended successfully',
      shift: updatedShift,
      summary: {
        expectedCash,
        actualCash: endingCash,
        difference: cashDifference,
        isOver: cashDifference > 0,
        isShort: cashDifference < 0
      }
    });
  } catch (error) {
    next(error);
  }
};

// Pay in (add cash to register)
const payIn = async (req, res, next) => {
  try {
    const { amount, note } = req.body;
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    
    const { data: transaction, error } = await supabaseAdmin
      .from('transactions')
      .insert({
        business_id: businessId,
        cashier_id: cashierId,
        type: 'pay_in',
        total_amount: amount,
        payment_method: 'cash',
        status: 'completed',
        note: note || 'Cash added to register'
      })
      .select()
      .single();
    
    if (error) throw error;
    
    res.status(201).json({
      message: 'Pay in recorded successfully',
      transaction
    });
  } catch (error) {
    next(error);
  }
};

// Pay out (remove cash from register)
const payOut = async (req, res, next) => {
  try {
    const { amount, note } = req.body;
    const businessId = req.user.business_id;
    const cashierId = req.user.id;
    
    const { data: transaction, error } = await supabaseAdmin
      .from('transactions')
      .insert({
        business_id: businessId,
        cashier_id: cashierId,
        type: 'pay_out',
        total_amount: amount,
        payment_method: 'cash',
        status: 'completed',
        note: note || 'Cash removed from register'
      })
      .select()
      .single();
    
    if (error) throw error;
    
    res.status(201).json({
      message: 'Pay out recorded successfully',
      transaction
    });
  } catch (error) {
    next(error);
  }
};

// Helper function to calculate total cash from denomination counts
const calculateTotalCash = (counts) => {
  const denominations = {
    pennies: 1,
    nickels: 5,
    dimes: 10,
    quarters: 25,
    ones: 100,
    twos: 200,
    fives: 500,
    tens: 1000,
    twenties: 2000,
    fifties: 5000,
    hundreds: 10000
  };
  
  return Object.entries(counts).reduce((total, [denom, count]) => {
    return total + (denominations[denom] || 0) * count;
  }, 0);
};

module.exports = {
  startDay,
  endDay,
  payIn,
  payOut
};