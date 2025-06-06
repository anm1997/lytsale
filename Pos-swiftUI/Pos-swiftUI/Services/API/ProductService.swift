import Foundation

class ProductService: ObservableObject {
    static let shared = ProductService()
    
    @Published var products: [Product] = []
    @Published var isLoading = false
    
    private let api = APIClient.shared
    
    private init() {}
    
    // MARK: - Product Methods
    
    // Get all products
    func fetchProducts(departmentId: UUID? = nil, search: String? = nil, limit: Int = 50, offset: Int = 0) async throws {
        await MainActor.run {
            self.isLoading = true
        }
        
        var endpoint = "/products?limit=\(limit)&offset=\(offset)"
        
        if let departmentId = departmentId {
            endpoint += "&department_id=\(departmentId)"
        }
        
        if let search = search, !search.isEmpty {
            endpoint += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        do {
            let response = try await api.get(endpoint, responseType: ProductsResponse.self)
            
            await MainActor.run {
                self.products = response.products
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Get product by ID
    func getProduct(id: UUID) async throws -> Product {
        try await api.get("/products/\(id)", responseType: ProductResponse.self).product
    }
    
    // Get product by UPC
    func getProductByUPC(_ upc: String) async throws -> Product {
        try await api.get("/products/upc/\(upc)", responseType: ProductResponse.self).product
    }
    
    // Create product
    func createProduct(_ request: ProductRequest) async throws -> Product {
        let response = try await api.post("/products", body: request, responseType: ProductResponse.self)
        
        // Add to local list
        await MainActor.run {
            self.products.append(response.product)
        }
        
        return response.product
    }
    
    // Update product
    func updateProduct(id: UUID, request: ProductRequest) async throws -> Product {
        let response = try await api.put("/products/\(id)", body: request, responseType: ProductResponse.self)
        
        // Update local list
        await MainActor.run {
            if let index = self.products.firstIndex(where: { $0.id == id }) {
                self.products[index] = response.product
            }
        }
        
        return response.product
    }
    
    // Delete product
    func deleteProduct(id: UUID) async throws {
        try await api.delete("/products/\(id)")
        
        // Remove from local list
        await MainActor.run {
            self.products.removeAll { $0.id == id }
        }
    }
    
    // Bulk import products
    func bulkImportProducts(_ products: [ProductRequest]) async throws -> BulkImportResponse {
        let body = ["products": products]
        return try await api.post("/products/bulk-import", body: body, responseType: BulkImportResponse.self)
    }
}

// MARK: - Response Types

struct ProductResponse: Codable {
    let product: Product
    let message: String?
}

struct BulkImportResponse: Codable {
    let message: String
    let imported: Int
    let errors: [String]?
}
