
import Foundation
import Supabase

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let api = APIClient.shared
    
    private init() {
        // Check for existing session on init
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Authentication Methods
    
    // Sign up new business owner
    func signUp(email: String, password: String, businessName: String, businessType: String, taxRate: Double) async throws -> User {
        let body = [
            "email": email,
            "password": password,
            "businessName": businessName,
            "businessType": businessType,
            "taxRate": taxRate
        ] as [String : Any]
        
        let response = try await api.post("/auth/signup", body: body, responseType: SignupResponse.self)
        
        // Save session
        if let session = response.session {
            api.setAuthToken(session.accessToken)
        }
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
        
        return response.user
    }
    
    // Verify OTP
    func verifyOTP(email: String, token: String) async throws {
        let body = [
            "email": email,
            "token": token
        ]
        
        let response = try await api.post("/auth/verify-otp", body: body, responseType: OTPResponse.self)
        
        await MainActor.run {
            if let user = response.user {
                self.currentUser?.emailVerified = true
            }
        }
    }
    
    // Login with email/password
    func login(email: String, password: String) async throws -> User {
        let body = [
            "email": email,
            "password": password
        ]
        
        let response = try await api.post("/auth/login", body: body, responseType: LoginResponse.self)
        
        // Save session
        if let session = response.session {
            api.setAuthToken(session.accessToken)
        }
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
        
        return response.user
    }
    
    // Login with cashier PIN
    func loginWithPIN(businessId: String, pin: String) async throws -> User {
        let body = [
            "businessId": businessId,
            "pin": pin
        ]
        
        let response = try await api.post("/auth/login-cashier", body: body, responseType: CashierLoginResponse.self)
        
        // Save token for cashier
        if let token = response.token {
            api.setAuthToken(token)
        }
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
        
        return response.user
    }
    
    // Logout
    func logout() async throws {
        try await api.post("/auth/logout")
        
        api.setAuthToken(nil)
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // Check current session
    func checkSession() async {
        guard api.authToken != nil else {
            await MainActor.run {
                self.isAuthenticated = false
            }
            return
        }
        
        do {
            let response = try await api.get("/auth/me", responseType: MeResponse.self)
            
            await MainActor.run {
                self.currentUser = response.user
                self.isAuthenticated = true
            }
        } catch {
            // Session invalid
            api.setAuthToken(nil)
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    // Resend OTP
    func resendOTP(email: String) async throws {
        let body = ["email": email]
        try await api.post("/auth/resend-otp", body: body)
    }
    
    // Get cashier list for PIN pad
    func getCashierList(businessId: String) async throws -> [Cashier] {
        let response = try await api.get("/users/business/\(businessId)/cashiers", responseType: CashierListResponse.self)
        return response.cashiers
    }
}

// MARK: - Response Types

struct SignupResponse: Codable {
    let message: String
    let user: User
    let business: Business
    let session: Session?
}

struct OTPResponse: Codable {
    let message: String
    let user: User?
}

struct CashierLoginResponse: Codable {
    let message: String
    let user: User
    let token: String?
}

struct MeResponse: Codable {
    let user: User
}

struct Cashier: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct CashierListResponse: Codable {
    let cashiers: [Cashier]
}
