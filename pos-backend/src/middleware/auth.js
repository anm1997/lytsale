const { supabase, supabaseAdmin } = require('../config/supabase');

const authenticate = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const { data: { user }, error } = await supabase.auth.getUser(token);
    
    if (error || !user) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    // Get additional user data including business_id
    const { data: userData, error: userError } = await supabaseAdmin
      .from('users')
      .select('*, businesses(*)')
      .eq('id', user.id)
      .single();

    if (userError || !userData) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = {
      ...user,
      ...userData,
      business: userData.businesses
    };
    
    next();
  } catch (error) {
    res.status(401).json({ error: 'Authentication failed' });
  }
};

const authorize = (...roles) => {
  return async (req, res, next) => {
    try {
      if (!roles.includes(req.user.role)) {
        return res.status(403).json({ error: 'Insufficient permissions' });
      }
      next();
    } catch (error) {
      res.status(403).json({ error: 'Authorization failed' });
    }
  };
};

// Special middleware for cashier PIN authentication
const authenticateCashier = async (req, res, next) => {
  try {
    const { businessId, pin } = req.body;
    
    if (!businessId || !pin) {
      return res.status(400).json({ error: 'Business ID and PIN required' });
    }

    const { data: cashier, error } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('business_id', businessId)
      .eq('pin', pin)
      .eq('role', 'cashier')
      .single();

    if (error || !cashier) {
      return res.status(401).json({ error: 'Invalid PIN' });
    }

    req.user = cashier;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Authentication failed' });
  }
};

module.exports = { authenticate, authorize, authenticateCashier };