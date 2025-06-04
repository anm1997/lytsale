module.exports = {
    BUSINESS_TYPES: {
      RETAIL: 'retail',
      RESTAURANT: 'restaurant',
      CAFE: 'cafe'
    },
    
    USER_ROLES: {
      OWNER: 'owner',
      MANAGER: 'manager',
      CASHIER: 'cashier'
    },
    
    TRANSACTION_TYPES: {
      SALE: 'sale',
      REFUND: 'refund',
      VOID: 'void',
      PAY_IN: 'pay_in',
      PAY_OUT: 'pay_out'
    },
    
    PAYMENT_METHODS: {
      CASH: 'cash',
      CARD: 'card'
    },
    
    DEFAULT_DEPARTMENTS: [
      { name: 'Taxable', taxable: true, system: true },
      { name: 'Non-Taxable', taxable: false, system: true }
    ],
    
    STRIPE_CONNECT: {
      OAUTH_URL: 'https://connect.stripe.com/oauth/authorize',
      TOKEN_URL: 'https://connect.stripe.com/oauth/token',
      PAYOUT_SCHEDULE: {
        interval: 'weekly',
        weekly_anchor: 'monday'
      }
    },
    
    EMAIL_TYPES: {
      TRANSACTION_NOTIFICATION: 'transaction_notification',
      DAILY_SUMMARY: 'daily_summary',
      WEEKLY_PAYOUT: 'weekly_payout',
      WELCOME: 'welcome'
    }
  };