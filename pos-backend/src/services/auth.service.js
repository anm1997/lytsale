// src/services/auth.service.js
const { supabase, supabaseAdmin } = require('../config/supabase');
const { DEFAULT_DEPARTMENTS } = require('../config/constants');
// No JWT needed - Supabase handles sessions

// Create business and owner account
const createBusinessAndOwner = async ({ email, password, businessName, businessType, taxRate }) => {
  try {
    // 1. Sign up the user with Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${process.env.FRONTEND_URL}/verify-email`
      }
    });

    if (authError) {
      return { error: authError.message };
    }

    // 2. Create business record
    const { data: business, error: businessError } = await supabaseAdmin
      .from('businesses')
      .insert({
        name: businessName,
        type: businessType,
        tax_rate: taxRate,
        stripe_connected: false,
        settings: {
          currency: 'USD',
          timezone: 'America/New_York'
        }
      })
      .select()
      .single();

    if (businessError) {
      // Cleanup: delete the auth user if business creation fails
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
      return { error: 'Failed to create business' };
    }

    // 3. Create user profile
    const { data: userProfile, error: userError } = await supabaseAdmin
      .from('users')
      .insert({
        id: authData.user.id,
        email: email,
        business_id: business.id,
        role: 'owner',
        name: email.split('@')[0], // Default name from email
        email_verified: false
      })
      .select()
      .single();

    if (userError) {
      // Cleanup: delete business and auth user
      await supabaseAdmin.from('businesses').delete().eq('id', business.id);
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
      return { error: 'Failed to create user profile' };
    }

    // 4. Create default departments for the business
    const departmentsToCreate = DEFAULT_DEPARTMENTS.map(dept => ({
      ...dept,
      business_id: business.id
    }));

    await supabaseAdmin
      .from('departments')
      .insert(departmentsToCreate);

    // 5. Sign in the user immediately
    const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (signInError) {
      return { 
        error: 'Account created but login failed. Please try logging in manually.' 
      };
    }

    return {
      user: { ...authData.user, ...userProfile },
      business,
      session: signInData.session
    };
  } catch (error) {
    console.error('Signup error:', error);
    return { error: 'An unexpected error occurred' };
  }
};

// Get user with business details
const getUserWithBusiness = async (userId) => {
  const { data, error } = await supabaseAdmin
    .from('users')
    .select(`
      *,
      businesses (
        id,
        name,
        type,
        tax_rate,
        stripe_connected,
        stripe_account_id,
        settings
      )
    `)
    .eq('id', userId)
    .single();

  if (error) {
    throw new Error('Failed to fetch user details');
  }

  return data;
};

// Mark email as verified
const markEmailVerified = async (userId) => {
  const { error } = await supabaseAdmin
    .from('users')
    .update({ email_verified: true })
    .eq('id', userId);

  if (error) {
    throw new Error('Failed to update email verification status');
  }
};

// Authenticate cashier with PIN
const authenticateCashier = async (businessId, pin) => {
  try {
    // Find cashier by business_id and pin
    const { data: cashier, error } = await supabaseAdmin
      .from('users')
      .select(`
        *,
        businesses (
          id,
          name,
          type,
          tax_rate,
          settings
        )
      `)
      .eq('business_id', businessId)
      .eq('pin', pin)
      .eq('role', 'cashier')
      .eq('active', true)
      .single();

    if (error || !cashier) {
      return { error: 'Invalid PIN or cashier not found' };
    }

    return {
      user: cashier
    };
  } catch (error) {
    console.error('Cashier auth error:', error);
    return { error: 'Authentication failed' };
  }
};

module.exports = {
  createBusinessAndOwner,
  getUserWithBusiness,
  markEmailVerified,
  authenticateCashier
};