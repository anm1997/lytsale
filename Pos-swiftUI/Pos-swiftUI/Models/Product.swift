import Foundation

struct Product: Codable, Identifiable {
    let id: UUID
    let businessId: UUID
    let departmentId: UUID
    let upc: String?
    let name: String
    let price: Int // in cents
    let caseCost: Int? // in cents
    let unitsPerCase: Int?
    let margin: Double?
    let active: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Relationship
    var department: Department?
    
    enum CodingKeys: String, CodingKey {
        case id
        case businessId = "business_id"
        case departmentId = "department_id"
        case upc
        case name
        case price
        case caseCost = "case_cost"
        case unitsPerCase = "units_per_case"
        case margin
        case active
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case department
    }
    
    // Computed properties
    var formattedPrice: String {
        let dollars = Double(price) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    var unitCost: Double? {
        guard let caseCost = caseCost,
              let unitsPerCase = unitsPerCase,
              unitsPerCase > 0 else { return nil }
        return Double(caseCost) / Double(unitsPerCase) / 100.0
    }
    
    var calculatedMargin: Double? {
        guard let unitCost = unitCost, price > 0 else { return nil }
        let priceInDollars = Double(price) / 100.0
        return ((priceInDollars - unitCost) / priceInDollars) * 100
    }
}

// Product creation/update request
struct ProductRequest: Codable {
    let upc: String?
    let name: String
    let departmentId: UUID
    let price: Int
    let caseCost: Int?
    let unitsPerCase: Int?
    
    enum CodingKeys: String, CodingKey {
        case upc
        case name
        case departmentId = "department_id"
        case price
        case caseCost = "case_cost"
        case unitsPerCase = "units_per_case"
    }
}

// Product search response
struct ProductsResponse: Codable {
    let products: [Product]
    let total: Int
    let limit: Int
    let offset: Int
}
