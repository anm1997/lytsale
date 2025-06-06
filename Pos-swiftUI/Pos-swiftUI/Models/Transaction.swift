import Foundation

struct Transaction: Codable, Identifiable {
    let id: UUID
    let businessId: UUID
    let cashierId: UUID
    let cashierName: String
    let type: TransactionType
    let paymentMethod: PaymentMethod?
    
    // Amounts (all in cents)
    let subtotal: Int
    let taxAmount: Int
    let totalAmount: Int
    let processingFee: Int
    let netAmount: Int
    
    // Status
    let status: TransactionStatus
    let completedAt: Date?
    
    // Stripe
    let stripePaymentIntentId: String?
    let stripeChargeId: String?
    let stripeRefundId: String?
    
    // Refund/void info
    let originalTransactionId: UUID?
    let refunded: Bool
    let refundedAmount: Int
    let refundedAt: Date?
    let voided: Bool
    let voidedAt: Date?
    let voidReason: String?
    
    // Other
    let ageVerified: Bool
    let note: String?
    let createdAt: Date
    
    // Relationships
    var items: [TransactionItem]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case businessId = "business_id"
        case cashierId = "cashier_id"
        case cashierName = "cashier_name"
        case type
        case paymentMethod = "payment_method"
        case subtotal
        case taxAmount = "tax_amount"
        case totalAmount = "total_amount"
        case processingFee = "processing_fee"
        case netAmount = "net_amount"
        case status
        case completedAt = "completed_at"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case stripeChargeId = "stripe_charge_id"
        case stripeRefundId = "stripe_refund_id"
        case originalTransactionId = "original_transaction_id"
        case refunded
        case refundedAmount = "refunded_amount"
        case refundedAt = "refunded_at"
        case voided
        case voidedAt = "voided_at"
        case voidReason = "void_reason"
        case ageVerified = "age_verified"
        case note
        case createdAt = "created_at"
        case items = "transaction_items"
    }
    
    var formattedTotal: String {
        let dollars = Double(totalAmount) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case sale = "sale"
    case refund = "refund"
    case void = "void"
    case payIn = "pay_in"
    case payOut = "pay_out"
    
    var displayName: String {
        switch self {
        case .sale: return "Sale"
        case .refund: return "Refund"
        case .void: return "Void"
        case .payIn: return "Pay In"
        case .payOut: return "Pay Out"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "cash"
    case card = "card"
    
    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        }
    }
    
    var icon: String {
        switch self {
        case .cash: return "dollarsign.circle"
        case .card: return "creditcard"
        }
    }
}

enum TransactionStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    
    var displayColor: String {
        switch self {
        case .pending: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}

struct TransactionItem: Codable, Identifiable {
    let id: UUID
    let transactionId: UUID
    let productId: UUID?
    let productName: String
    let departmentId: UUID?
    let quantity: Int
    let price: Int // unit price in cents
    let taxAmount: Int
    let total: Int // total with tax
    
    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case productId = "product_id"
        case productName = "product_name"
        case departmentId = "department_id"
        case quantity
        case price
        case taxAmount = "tax_amount"
        case total
    }
    
    var formattedPrice: String {
        let dollars = Double(price) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    var formattedTotal: String {
        let dollars = Double(total) / 100.0
        return String(format: "$%.2f", dollars)
    }
}
