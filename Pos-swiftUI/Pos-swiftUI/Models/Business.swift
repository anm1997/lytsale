import Foundation

struct Business: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: BusinessType
    let taxRate: Double
    let address: Address?
    let settings: BusinessSettings
    
    // Stripe Connect
    let stripeAccountId: String?
    let stripeConnected: Bool
    let stripeConnectedAt: Date?
    
    // Email tracking
    let lastDayClosedAt: Date?
    let dailySummarySent: Bool
    let lastSummaryentAt: Date?
    
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case taxRate = "tax_rate"
        case address
        case settings
        case stripeAccountId = "stripe_account_id"
        case stripeConnected = "stripe_connected"
        case stripeConnectedAt = "stripe_connected_at"
        case lastDayClosedAt = "last_day_closed_at"
        case dailySummarySent = "daily_summary_sent"
        case lastSummaryentAt = "last_summary_sent_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum BusinessType: String, Codable, CaseIterable {
    case retail = "retail"
    case restaurant = "restaurant"
    case cafe = "cafe"
    
    var displayName: String {
        switch self {
        case .retail: return "Retail"
        case .restaurant: return "Restaurant"
        case .cafe: return "Cafe"
        }
    }
    
    var isEnabled: Bool {
        switch self {
        case .retail: return true
        case .restaurant, .cafe: return false // Phase 2
        }
    }
}

struct Address: Codable {
    let street: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case street
        case city
        case state
        case zipCode = "zip_code"
        case country
    }
}

struct BusinessSettings: Codable {
    let currency: String
    let timezone: String
    let receiptFooter: String?
    let requireCustomerReceipt: Bool
    let autoPrintReceipt: Bool
    
    enum CodingKeys: String, CodingKey {
        case currency
        case timezone
        case receiptFooter = "receipt_footer"
        case requireCustomerReceipt = "require_customer_receipt"
        case autoPrintReceipt = "auto_print_receipt"
    }
    
    static var defaultSettings: BusinessSettings {
        BusinessSettings(
            currency: "USD",
            timezone: "America/New_York",
            receiptFooter: nil,
            requireCustomerReceipt: false,
            autoPrintReceipt: true
        )
    }
}

// Dashboard Statistics
struct DashboardStats: Codable {
    let todaySales: Int
    let transactionCount: Int
    let productCount: Int
    let userCount: Int
    let recentTransactions: [Transaction]
    
    enum CodingKeys: String, CodingKey {
        case todaySales = "today_sales"
        case transactionCount = "transaction_count"
        case productCount = "product_count"
        case userCount = "user_count"
        case recentTransactions = "recent_transactions"
    }
}
