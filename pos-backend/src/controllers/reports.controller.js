// src/controllers/reports.controller.js
const reportService = require('../services/reports.service');

// Get daily summary
const getDailySummary = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { date } = req.query;
    
    if (!date) {
      return res.status(400).json({ error: 'Date parameter required' });
    }
    
    const summary = await reportService.generateDailySummary(
      businessId, 
      new Date(date)
    );
    
    res.json({ summary });
  } catch (error) {
    next(error);
  }
};

// Get shift report
const getShiftReport = async (req, res, next) => {
  try {
    const { shiftId } = req.params;
    
    const report = await reportService.generateShiftReport(shiftId);
    
    // Verify shift belongs to user's business
    if (report.shift.business_id !== req.user.business_id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    res.json({ report });
  } catch (error) {
    next(error);
  }
};

// Get product performance report
const getProductReport = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { startDate, endDate } = req.query;
    
    if (!startDate || !endDate) {
      return res.status(400).json({ 
        error: 'Start date and end date parameters required' 
      });
    }
    
    const report = await reportService.generateProductReport(
      businessId,
      startDate,
      endDate
    );
    
    res.json({ report });
  } catch (error) {
    next(error);
  }
};

// Get hourly sales report
const getHourlyReport = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { date } = req.query;
    
    if (!date) {
      return res.status(400).json({ error: 'Date parameter required' });
    }
    
    const report = await reportService.generateHourlyReport(
      businessId,
      new Date(date)
    );
    
    res.json({ report });
  } catch (error) {
    next(error);
  }
};

// Get sales summary for date range
const getSalesSummary = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { startDate, endDate, groupBy = 'day' } = req.query;
    
    if (!startDate || !endDate) {
      return res.status(400).json({ 
        error: 'Start date and end date parameters required' 
      });
    }
    
    // Generate summary for each day in range
    const summaries = [];
    const start = new Date(startDate);
    const end = new Date(endDate);
    
    for (let date = new Date(start); date <= end; date.setDate(date.getDate() + 1)) {
      const summary = await reportService.generateDailySummary(
        businessId,
        new Date(date)
      );
      summaries.push(summary);
    }
    
    // Aggregate totals
    const totals = summaries.reduce((acc, day) => ({
      totalSales: acc.totalSales + day.totalSales,
      totalRefunds: acc.totalRefunds + day.totalRefunds,
      netSales: acc.netSales + day.netSales,
      cashSales: acc.cashSales + day.cashSales,
      cardSales: acc.cardSales + day.cardSales,
      totalTransactions: acc.totalTransactions + day.totalTransactions,
      totalFees: acc.totalFees + day.totalFees,
      netAmount: acc.netAmount + day.netAmount
    }), {
      totalSales: 0,
      totalRefunds: 0,
      netSales: 0,
      cashSales: 0,
      cardSales: 0,
      totalTransactions: 0,
      totalFees: 0,
      netAmount: 0
    });
    
    res.json({
      period: {
        start: startDate,
        end: endDate
      },
      totals,
      dailySummaries: summaries,
      averageDailySales: summaries.length > 0 ? 
        Math.round(totals.totalSales / summaries.length) : 0
    });
  } catch (error) {
    next(error);
  }
};

// Export report as CSV
const exportReport = async (req, res, next) => {
  try {
    const businessId = req.user.business_id;
    const { type, startDate, endDate } = req.query;
    
    if (!type || !startDate || !endDate) {
      return res.status(400).json({ 
        error: 'Type, start date and end date required' 
      });
    }
    
    let data;
    let filename;
    
    switch (type) {
      case 'products':
        const productReport = await reportService.generateProductReport(
          businessId,
          startDate,
          endDate
        );
        data = productReport.products;
        filename = `products_${startDate}_${endDate}.csv`;
        break;
        
      case 'daily':
        const dailySummary = await reportService.generateDailySummary(
          businessId,
          new Date(startDate)
        );
        data = [dailySummary];
        filename = `daily_summary_${startDate}.csv`;
        break;
        
      default:
        return res.status(400).json({ error: 'Invalid report type' });
    }
    
    // Convert to CSV
    if (data.length === 0) {
      return res.status(404).json({ error: 'No data found for export' });
    }
    
    const headers = Object.keys(data[0]);
    const csvContent = [
      headers.join(','),
      ...data.map(row => 
        headers.map(header => {
          const value = row[header];
          // Handle nested objects and arrays
          if (typeof value === 'object') {
            return JSON.stringify(value);
          }
          // Escape commas and quotes
          return `"${String(value).replace(/"/g, '""')}"`;
        }).join(',')
      )
    ].join('\n');
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csvContent);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getDailySummary,
  getShiftReport,
  getProductReport,
  getHourlyReport,
  getSalesSummary,
  exportReport
};