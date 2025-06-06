import Foundation

class CheckoutService: ObservableObject {
    static let shared = CheckoutService()
    
    @Published var currentTransaction: Transaction?
    @Published var isProcessing = false
    
    private let api = APIClient.shared
    private var currentSessionId: String?
    
    private init() {}
    
    // MARK: - Checkout Methods
    
    // Start new checkout session
    func startCheckout() async throws -> CheckoutSession {
        let response = try await api.post("/checkout/start", responseType: CheckoutSessionResponse.self)
        currentSessionId = response.sessionId
        return response
    }
    
    // Add item to checkout (validate restrictions)
    func addItem(upc: String? = nil, departmentId: UUID? = nil, price: Int? = nil, quantity: Int = 1) async throws -> AddItemResponse {
        var body: [String: Any] = ["quantity": quantity]
        
        if let upc = upc {
            body["upc"] = upc
        }
        if let departmentId = departmentId {
            body["departmentId"] = departmentId.uuidString
        }
        if let price = price {
            body["price"] = price
        }
        
        return try await api.post("/checkout/add-item", body: body, responseType: AddItemResponse.self)
    }
    
    // Verify customer age
    func verifyAge(confirmed: Bool, customerAge: Int? = nil) async throws {
        let body: [String: Any] = [
            "confirmed": confirmed,
            "customerAge": customerAge ?? 0
        ]
        
        try await api.post("/checkout/verify-age", body: body)
    }
    
    // Process payment
    func processPayment(cart: Cart, paymentMethod: PaymentMethod, cashReceived: Int? = nil) async throws -> PaymentResponse {
        // Convert cart items to API format
        let items = cart.items.map { item in
            [
                "productId": item.product.id.uuidString,
                "productName": item.product.name,
                "departmentId": item.product.departmentId.uuidString,
                "quantity": item.quantity,
                "price": item.price,
                "taxAmount": item.taxAmount,
                "totalWithTax": item.totalWithTax,
                "ageRestriction": item.ageRestriction as Any
            ]
        }
        
        var body: [String: Any] = [
            "items": items,
            "paymentMethod": paymentMethod.rawValue,
            "subtotal": cart.subtotal,
            "taxAmount": cart.taxAmount,
            "totalAmount": cart.total,
            "customerAgeVerified": cart.customerAgeVerified
        ]
        
        if paymentMethod == .cash, let cashReceived = cashReceived {
            body["cashReceived"] = cashReceived
        }
        
        let response = try await api.post("/checkout/payment", body: body, responseType: PaymentResponse.self)
        
        await MainActor.run {
            self.currentTransaction = response.transaction
        }
        
        return response
    }
    
    // Confirm card payment (after Stripe processing)
    func confirmCardPayment(transactionId: UUID, paymentIntentId: String) async throws {
        let body = [
            "transactionId": transactionId.uuidString,
            "paymentIntentId": paymentIntentId
        ]
        
        try await api.post("/checkout/confirm-card-payment", body: body)
        
        await MainActor.run {
            self.currentTransaction?.status = .completed
        }
    }
    
    // Get transaction history
    func getTransactions(startDate: Date? = nil, endDate: Date? = nil, limit: Int = 50) async throws -> [Transaction] {
        var endpoint = "/transactions?limit=\(limit)"
        
        if let startDate = startDate {
            endpoint += "&startDate=\(ISO8601DateFormatter().string(from: startDate))"
        }
        if let endDate = endDate {
            endpoint += "&endDate=\(ISO8601DateFormatter().string(from: endDate))"
        }
        
        let response = try await api.get(endpoint, responseType: TransactionsResponse.self)
        return response.transactions
    }
    
    // Process refund
    func processRefund(transactionId: UUID, items: [RefundItem]? = nil, reason: String? = nil) async throws -> Transaction {
        let body: [String: Any] = [
            "items": items?.map { ["itemId": $0.itemId.uuidString, "quantity": $0.quantity] } ?? [],
            "reason": reason ?? ""
        ]
        
        let response = try await api.post("/transactions/\(transactionId)/refund", body: body, responseType: RefundResponse.self)
        return response.refundTransaction
    }
    
    // Void transaction
    func voidTransaction(transactionId: UUID, reason: String? = nil) async throws {
        let body = ["reason": reason ?? ""]
        try await api.post("/transactions/\(transactionId)/void", body: body)
    }
}

// MARK: - Response Types

struct CheckoutSession: Codable {
    let sessionId: String
    let cashier: String
    let businessId: UUID
    let startedAt: Date
}

typealias CheckoutSessionResponse = CheckoutSession

struct AddItemResponse: Codable {
    let item: CheckoutItem
    let requiresAgeCheck: Bool
}

struct CheckoutItem: Codable {
    let productId: UUID?
    let name: String
    let price: Int
    let departmentId: UUID
    let department: Department
    let taxable: Bool
    let ageRestriction: Int?
    let timeRestriction: TimeRestriction?
    let quantity: Int
    let itemTax: Int
    let totalPrice: Int
    let totalTax: Int
    let totalWithTax: Int
}

struct PaymentResponse: Codable {
    let transaction: Transaction
    let payment: PaymentResult
    let items: [TransactionItem]
}

struct PaymentResult: Codable {
    let method: String
    let status: String
    let clientSecret: String?
    let paymentIntentId: String?
    let received: Int?
    let change: Int?
}

struct TransactionsResponse: Codable {
    let transactions: [Transaction]
    let total: Int
    let limit: Int
    let offset: Int
}

struct RefundItem: Codable {
    let itemId: UUID
    let quantity: Int
}

struct RefundResponse: Codable {
    let message: String
    let refundTransaction: Transaction
    let refundAmount: Int
}
