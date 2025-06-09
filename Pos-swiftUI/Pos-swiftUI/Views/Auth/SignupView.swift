import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var businessName = ""
    @State private var businessType = BusinessType.retail
    @State private var taxRate = ""
    
    @State private var showingOTPVerification = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "building.2.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Create Your Business Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Get started with Lytsale POS")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 25) {
                        // Business Information Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Business Information")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("Business Name", text: $businessName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title3)
                                .frame(height: 50)
                            
                            // Business Type Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Business Type")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Business Type", selection: $businessType) {
                                    ForEach(BusinessType.allCases, id: \.self) { type in
                                        Text(type.displayName)
                                            .tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .disabled(true) // Only retail for now
                            }
                            
                            // Tax Rate
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sales Tax Rate (%)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("8.875", text: $taxRate)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                    .font(.title3)
                                    .frame(height: 50)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Account Information Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Account Information")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .font(.title3)
                                .frame(height: 50)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title3)
                                .frame(height: 50)
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title3)
                                .frame(height: 50)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Sign Up Button
                        Button(action: signUp) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isFormValid || isLoading)
                        
                        // Terms
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 600)
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingOTPVerification) {
            OTPVerificationView(email: email)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        !businessName.isEmpty &&
        !taxRate.isEmpty
    }
    
    private func signUp() {
        guard let taxRateDouble = Double(taxRate) else {
            errorMessage = "Invalid tax rate"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                _ = try await authService.signUp(
                    email: email,
                    password: password,
                    businessName: businessName,
                    businessType: businessType.rawValue,
                    taxRate: taxRateDouble / 100.0 // Convert percentage to decimal
                )
                
                await MainActor.run {
                    showingOTPVerification = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}
