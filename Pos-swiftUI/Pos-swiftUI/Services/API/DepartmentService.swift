import Foundation

class DepartmentService: ObservableObject {
    static let shared = DepartmentService()
    
    @Published var departments: [Department] = []
    @Published var isLoading = false
    
    private let api = APIClient.shared
    
    private init() {}
    
    // MARK: - Department Methods
    
    // Get all departments
    func fetchDepartments() async throws {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let response = try await api.get("/departments", responseType: DepartmentsResponse.self)
            
            await MainActor.run {
                self.departments = response.departments
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Get department by ID
    func getDepartment(id: UUID) async throws -> Department {
        try await api.get("/departments/\(id)", responseType: DepartmentResponse.self).department
    }
    
    // Create department
    func createDepartment(_ request: DepartmentRequest) async throws -> Department {
        let response = try await api.post("/departments", body: request, responseType: DepartmentResponse.self)
        
        // Add to local list
        await MainActor.run {
            self.departments.append(response.department)
        }
        
        return response.department
    }
    
    // Update department
    func updateDepartment(id: UUID, request: DepartmentRequest) async throws -> Department {
        let response = try await api.put("/departments/\(id)", body: request, responseType: DepartmentResponse.self)
        
        // Update local list
        await MainActor.run {
            if let index = self.departments.firstIndex(where: { $0.id == id }) {
                self.departments[index] = response.department
            }
        }
        
        return response.department
    }
    
    // Delete department
    func deleteDepartment(id: UUID) async throws {
        try await api.delete("/departments/\(id)")
        
        // Remove from local list
        await MainActor.run {
            self.departments.removeAll { $0.id == id }
        }
    }
    
    // Get non-system departments (for user management)
    var userDepartments: [Department] {
        departments.filter { !$0.system }
    }
    
    // Get system departments
    var systemDepartments: [Department] {
        departments.filter { $0.system }
    }
    
    // Find department by name
    func findDepartment(named name: String) -> Department? {
        departments.first { $0.name.lowercased() == name.lowercased() }
    }
}

// MARK: - Response Types

struct DepartmentsResponse: Codable {
    let departments: [Department]
}

struct DepartmentResponse: Codable {
    let department: Department
    let message: String?
}
