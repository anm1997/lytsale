import Foundation
import SwiftUI

// MARK: - App Constants

struct Constants {
    
    // MARK: - API Configuration
    struct API {
        #if DEBUG
        static let baseURL = "http://localhost:3000/api"
        #else
        static let baseURL = "https://api.lytsale.com/api"
        #endif
        
        static let timeout: TimeInterval = 30
    }
    
    // MARK: - Supabase Configuration
    struct Supabase {
        // TODO: Replace with your actual Supabase credentials
        static let url = "https://your-project.supabase.co"
        static let anonKey = "your-anon-key"
    }
    
    // MARK: - Stripe Configuration
    struct Stripe {
        // TODO: Replace with your actual Stripe publishable key
        #if DEBUG
        static let publishableKey = "pk_test_your_test_key"
        #else
        static let publishableKey = "pk_live_your_live_key"
        #endif
    }
    
    // MARK: - App Configuration
    struct App {
        static let name = "Lytsale"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - UI Constants
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let animationDuration: Double = 0.3
        
        // Grid layout for products
        static let productGridColumns = 4
        static let productCardMinWidth: CGFloat = 200
        static let productCardHeight: CGFloat = 250
        
        // PIN pad
        static let pinLength = 4
        static let pinPadButtonSize: CGFloat = 80
        
        // Scanner
        static let scannerFrameSize: CGFloat = 300
    }
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.blue
        static let secondary = Color.gray
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    }
    
    // MARK: - Storage Keys
    struct Storage {
        static let authToken = "authToken"
        static let currentUser = "currentUser"
        static let businessId = "businessId"
        static let lastSyncDate = "lastSyncDate"
    }
    
    // MARK: - Validation
    struct Validation {
        static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        static let passwordMinLength = 6
        static let upcMinLength = 8
        static let upcMaxLength = 14
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let networkError = "Network connection error. Please check your internet connection."
        static let invalidCredentials = "Invalid email or password."
        static let sessionExpired = "Your session has expired. Please login again."
        static let genericError = "Something went wrong. Please try again."
        static let ageRestricted = "Customer must be %d or older to purchase this item."
        static let timeRestricted = "This product cannot be sold at this time."
    }
    
    // MARK: - Success Messages
    struct SuccessMessages {
        static let productAdded = "Product added successfully"
        static let productUpdated = "Product updated successfully"
        static let transactionComplete = "Transaction completed successfully"
        static let refundProcessed = "Refund processed successfully"
    }
}
