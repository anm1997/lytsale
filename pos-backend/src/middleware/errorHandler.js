const errorHandler = (err, req, res, next) => {
    console.error(err.stack);
  
    // Supabase errors
    if (err.code && err.message && err.code.startsWith('PGRST')) {
      return res.status(400).json({
        error: err.message,
        code: err.code
      });
    }
  
    // Stripe errors
    if (err.type && err.type.includes('Stripe')) {
      return res.status(400).json({
        error: err.message,
        code: err.code
      });
    }
  
    // Validation errors
    if (err.name === 'ValidationError') {
      return res.status(400).json({
        error: 'Validation Error',
        details: err.errors
      });
    }
  
    // Default error
    res.status(err.status || 500).json({
      error: err.message || 'Internal Server Error',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
  };
  
  module.exports = errorHandler;