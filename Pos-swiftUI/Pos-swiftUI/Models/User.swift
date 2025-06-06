import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let businessId: UUID
    let role: UserRole
    let name: String
    let email: String?
    let emailVerified: Bool
    let active: Bool
    let createdAt: Date
    let updatedAt: Date
    let lastLogin: Date?
    
    // Business relationship
    var business: Business?
    
    enum CodingKeys: String, CodingKey {
        case id
        case businessId = "business_id"
        case role
        case name
        case email
        case emailVerified = "email_verified"
        case active
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLogin = "last_login"
        case business
    }
}

enum UserRole: String, Codable, CaseIterable {
    case owner = "owner"
    case manager = "manager"
    case cashier = "cashier"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .manager: return "Manager"
        case .cashier: return "Cashier"
        }
    }
    
    var permissions: Set<Permission> {
        switch self {
        case .owner:
            return Set(Permission.allCases)
        case .manager:
            return [.viewReports, .manageProducts, .manageDepartments, .processTransactions, .manageShifts]
        case .cashier:
            return [.processTransactions, .viewOwnShift]
        }
    }
}

enum Permission: String, CaseIterable {
    case viewReports
    case manageProducts
    case manageDepartments
    case manageUsers
    case processTransactions
    case manageShifts
    case viewOwnShift
    case updateBusinessSettings
}

// Login Response
struct LoginResponse: Codable {
    let user: User
    let session: Session?
    let token: String?
}

struct Session: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
