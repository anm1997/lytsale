import Foundation

// Cart model for managing checkout state
class Cart: ObservableObject {
    @Published var items: [CartItem] = []
    @Published var customerAgeVerified: Bool = false
    @Published var verifiedAge: Int? = nil
    
    var subtotal: Int {
        items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var taxAmount: Int {
        items.reduce(0) { $0 + $1.taxAmount }
    }
    
    var total: Int {
        subtotal + taxAmount
    }
    
    var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    
    var requiresAgeVerification: Bool {
        items.contains { $0.ageRestriction != nil }
    }
    
    var highestAgeRequirement: Int? {
        items.compactMap { $0.ageRestriction }.max()
    }
    
    func addItem(_ product: Product, quantity: Int = 1, taxRate: Double) {
        if let existingIndex = items.firstIndex(where: { $0.product.id == product.id }) {
            items[existingIndex].quantity += quantity
        } else {
            let cartItem = CartItem(
                product: product,
                quantity: quantity,
                taxRate: taxRate
            )
            items.append(cartItem)
        }
    }
    
    func removeItem(at index: Int) {
        items.remove(at: index)
    }
    
    func updateQuantity(at index: Int, quantity: Int) {
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }
    }
    
    func clear() {
        items.removeAll()
        customerAgeVerified = false
        verifiedAge = nil
    }
    
    func verifyAge(_ age: Int) {
        verifiedAge = age
        customerAgeVerified = true
    }
}

struct CartItem: Identifiable {
    let id = UUID()
    let product: Product
    var quantity: Int
    let taxRate: Double
    
    var price: Int {
        product.price
    }
    
    var totalPrice: Int {
        price * quantity
    }
    
    var taxAmount: Int {
        guard let department = product.department,
              department.taxable else { return 0 }
        return Int(Double(totalPrice) * taxRate)
    }
    
    var totalWithTax: Int {
        totalPrice + taxAmount
    }
    
    var ageRestriction: Int? {
        product.department?.ageRestriction
    }
    
    var formattedPrice: String {
        let dollars = Double(price) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    var formattedTotal: String {
        let dollars = Double(totalWithTax) / 100.0
        return String(format: "$%.2f", dollars)
    }
}

// Manual entry item for non-cataloged products
struct ManualEntryItem {
    let departmentId: UUID
    let department: Department
    let price: Int
    let quantity: Int
    
    var taxAmount: Int {
        guard department.taxable else { return 0 }
        // Tax rate would come from business settings
        return 0 // Will be calculated with actual tax rate
    }
}
