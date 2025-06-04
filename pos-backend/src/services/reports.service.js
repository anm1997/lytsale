// src/services/reports.service.js
const { supabaseAdmin } = require('../config/supabase');
const { calculateApplicationFee } = require('../config/stripe');

// Generate daily summary data
const generateDailySummary = async (businessId, date) => {
  try {
    // Set date range for the day
    const startDate = new Date(date);
    startDate.setHours(0, 0, 0, 0);
    
    const endDate = new Date(date);
    endDate.setHours(23, 59, 59, 999);
    
    // Get all transactions for the day
    const { data: transactions, error } = await supabaseAdmin
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
      `)
      .eq('business_id', businessId)
      .gte('created_at', startDate.toISOString())
      .lte('created_at', endDate.toISOString())
      .in('type', ['sale', 'refund']);
    
    if (error) throw error;
    
    // Calculate totals
    const sales = transactions.filter(t => t.type === 'sale' && t.status === 'completed');
    const refunds = transactions.filter(t => t.type === 'refund' && t.status === 'completed');
    
    const totalSales = sales.reduce((sum, t) => sum + t.total_amount, 0);
    const totalRefunds = Math.abs(refunds.reduce((sum, t) => sum + t.total_amount, 0));
    const netSales = totalSales - totalRefunds;
    
    // Separate by payment method
    const cashSales = sales
      .filter(t => t.payment_method === 'cash')
      .reduce((sum, t) => sum + t.total_amount, 0);
    
    const cardSales = sales
      .filter(t => t.payment_method === 'card')
      .reduce((sum, t) => sum + t.total_amount, 0);
    
    // Calculate total fees for card transactions
    const totalFees = sales
      .filter(t => t.payment_method === 'card')
      .reduce((sum, t) => sum + (t.processing_fee || 0), 0);
    
    const netAmount = cardSales - totalFees;
    
    // Get top products
    const productSales = {};
    sales.forEach(transaction => {
      transaction.transaction_items.forEach(item => {
        const key = item.product_id || item.product_name;
        if (!productSales[key]) {
          productSales[key] = {
            name: item.products?.name || item.product_name,
            quantity: 0,
            revenue: 0
          };
        }
        productSales[key].quantity += item.quantity;
        productSales[key].revenue += item.total;
      });
    });
    
    const topProducts = Object.values(productSales)
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 10);
    
    // Hourly breakdown
    const hourlyBreakdown = Array(24).fill(0);
    sales.forEach(transaction => {
      const hour = new Date(transaction.created_at).getHours();
      hourlyBreakdown[hour] += transaction.total_amount;
    });
    
    return {
      date: date.toISOString(),
      totalSales,
      totalRefunds,
      netSales,
      cashSales,
      cardSales,
      totalTransactions: sales.length,
      totalFees,
      netAmount,
      topProducts,
      hourlyBreakdown,
      averageTransaction: sales.length > 0 ? Math.round(totalSales / sales.length) : 0
    };
  } catch (error) {
    console.error('Error generating daily summary:', error);
    throw error;
  }
};

// Generate shift report
const generateShiftReport = async (shiftId) => {
  try {
    const { data: shift, error: shiftError } = await supabaseAdmin
      .from('shifts')
      .select(`
        *,
        users (
          name,
          email
        ),
        businesses (
          name,
          tax_rate
        )
      `)
      .eq('id', shiftId)
      .single();
    
    if (shiftError) throw shiftError;
    
    // Get transactions during shift
    const { data: transactions, error: transError } = await supabaseAdmin
      .from('transactions')
      .select(`
        *,
        transaction_items (*)
      `)
      .eq('business_id', shift.business_id)
      .gte('created_at', shift.started_at)
      .lte('created_at', shift.ended_at || new Date().toISOString());
    
    if (transError) throw transError;
    
    // Calculate metrics
    const sales = transactions.filter(t => t.type === 'sale');
    const refunds = transactions.filter(t => t.type === 'refund');
    
    const metrics = {
      totalSales: sales.reduce((sum, t) => sum + t.total_amount, 0),
      totalRefunds: Math.abs(refunds.reduce((sum, t) => sum + t.total_amount, 0)),
      cashSales: sales.filter(t => t.payment_method === 'cash').reduce((sum, t) => sum + t.total_amount, 0),
      cardSales: sales.filter(t => t.payment_method === 'card').reduce((sum, t) => sum + t.total_amount, 0),
      transactionCount: sales.length,
      refundCount: refunds.length,
      itemsSold: sales.reduce((sum, t) => sum + t.transaction_items.reduce((s, i) => s + i.quantity, 0), 0)
    };
    
    return {
      shift,
      metrics,
      cashReconciliation: {
        startingCash: shift.starting_cash,
        expectedCash: shift.expected_cash,
        actualCash: shift.ending_cash,
        difference: shift.cash_difference
      }
    };
  } catch (error) {
    console.error('Error generating shift report:', error);
    throw error;
  }
};

// Generate product performance report
const generateProductReport = async (businessId, startDate, endDate) => {
  try {
    // Get all transaction items in date range
    const { data: items, error } = await supabaseAdmin
      .from('transaction_items')
      .select(`
        *,
        products (
          name,
          upc,
          department_id,
          margin
        ),
        departments (
          name
        ),
        transactions!inner (
          business_id,
          created_at,
          type,
          status
        )
      `)
      .eq('transactions.business_id', businessId)
      .eq('transactions.type', 'sale')
      .eq('transactions.status', 'completed')
      .gte('transactions.created_at', startDate)
      .lte('transactions.created_at', endDate);
    
    if (error) throw error;
    
    // Aggregate by product
    const productStats = {};
    
    items.forEach(item => {
      const key = item.product_id || item.product_name;
      
      if (!productStats[key]) {
        productStats[key] = {
          productId: item.product_id,
          name: item.products?.name || item.product_name,
          upc: item.products?.upc,
          department: item.departments?.name || 'Unknown',
          quantity: 0,
          revenue: 0,
          tax: 0,
          transactions: 0,
          margin: item.products?.margin
        };
      }
      
      productStats[key].quantity += item.quantity;
      productStats[key].revenue += item.total;
      productStats[key].tax += item.tax_amount || 0;
      productStats[key].transactions += 1;
    });
    
    // Convert to array and sort by revenue
    const products = Object.values(productStats)
      .sort((a, b) => b.revenue - a.revenue);
    
    // Calculate department totals
    const departmentTotals = {};
    products.forEach(product => {
      if (!departmentTotals[product.department]) {
        departmentTotals[product.department] = {
          name: product.department,
          revenue: 0,
          quantity: 0
        };
      }
      departmentTotals[product.department].revenue += product.revenue;
      departmentTotals[product.department].quantity += product.quantity;
    });
    
    return {
      period: {
        start: startDate,
        end: endDate
      },
      products,
      departmentTotals: Object.values(departmentTotals).sort((a, b) => b.revenue - a.revenue),
      summary: {
        totalProducts: products.length,
        totalRevenue: products.reduce((sum, p) => sum + p.revenue, 0),
        totalQuantity: products.reduce((sum, p) => sum + p.quantity, 0),
        totalTax: products.reduce((sum, p) => sum + p.tax, 0)
      }
    };
  } catch (error) {
    console.error('Error generating product report:', error);
    throw error;
  }
};

// Generate sales by hour report
const generateHourlyReport = async (businessId, date) => {
  try {
    const startDate = new Date(date);
    startDate.setHours(0, 0, 0, 0);
    
    const endDate = new Date(date);
    endDate.setHours(23, 59, 59, 999);
    
    const { data: transactions, error } = await supabaseAdmin
      .from('transactions')
      .select('created_at, total_amount, type')
      .eq('business_id', businessId)
      .eq('type', 'sale')
      .eq('status', 'completed')
      .gte('created_at', startDate.toISOString())
      .lte('created_at', endDate.toISOString());
    
    if (error) throw error;
    
    // Group by hour
    const hourlyData = Array(24).fill(null).map((_, hour) => ({
      hour,
      transactions: 0,
      revenue: 0
    }));
    
    transactions.forEach(transaction => {
      const hour = new Date(transaction.created_at).getHours();
      hourlyData[hour].transactions += 1;
      hourlyData[hour].revenue += transaction.total_amount;
    });
    
    return {
      date: date.toISOString(),
      hourlyData,
      peakHour: hourlyData.reduce((peak, current) => 
        current.revenue > peak.revenue ? current : peak
      ),
      totalRevenue: hourlyData.reduce((sum, h) => sum + h.revenue, 0),
      totalTransactions: hourlyData.reduce((sum, h) => sum + h.transactions, 0)
    };
  } catch (error) {
    console.error('Error generating hourly report:', error);
    throw error;
  }
};

module.exports = {
  generateDailySummary,
  generateShiftReport,
  generateProductReport,
  generateHourlyReport
};