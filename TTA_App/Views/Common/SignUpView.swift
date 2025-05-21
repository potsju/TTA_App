import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var coachAccessCode: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showMainTab = false
    @State private var showCoachView = false
    @State private var isCoachCodeValid = false
    
    private let validCoachCode = "8888"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // Logo
                    Image("TTALogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 117)
                        .padding(.top, -150)
                        .padding(.bottom, 13)
                    
                    // Form content
                    VStack(alignment: .leading, spacing: 0) {
                        // Coach access code field (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Coach Access Code (Optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack {
                                SecureField("Enter code if you are a coach", text: $coachAccessCode)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: coachAccessCode) { newValue in
                                        isCoachCodeValid = newValue == validCoachCode
                                    }
                                
                                if !coachAccessCode.isEmpty {
                                    Image(systemName: isCoachCodeValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isCoachCodeValid ? .green : .red)
                                        .font(.system(size: 20))
                                }
                            }
                            
                            if isCoachCodeValid {
                                Text("Valid coach code verified!")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                    .padding(.top, 4)
                            } else if !coachAccessCode.isEmpty {
                                Text("Invalid access code")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // Account creation fields
                        emailField
                        passwordField
                        passwordStrengthIndicator
                        passwordRequirementsText
                        createAccountButton
                    }
                }
                
                // Back button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .frame(width: 12, height: 20)
                        .foregroundColor(TailwindColors.gray500)
                        .padding(4)
                }.offset(y: -250)
            }
            .padding(.horizontal, 24)
            .padding(.top, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .navigationBarBackButtonHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    
        .navigationDestination(isPresented: $showCoachView) {
            CoachMainView()
                .navigationBarBackButtonHidden(true)
        }
    }
    
    private var emailField: some View {
        TextField("Email", text: $email)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
            .padding(.bottom, 16)
    }
    
    private var passwordField: some View {
        SecureField("Password", text: $password)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.bottom, 8)
    }
    
    private var passwordStrengthIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(getPasswordStrengthColor(index))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var passwordRequirementsText: some View {
        Text("Password must be at least 8 characters long and contain at least one number")
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .padding(.bottom, 24)
    }
    
    private var createAccountButton: some View {
        Button(action: createAccount) {
            Text("Create Account")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isCoachCodeValid ? TailwindColors.violet400 : TailwindColors.orange600)
                .cornerRadius(12)
        }
        .disabled(!isFormValid)
    }
    
    private var isFormValid: Bool {
        let emailValid = !email.isEmpty
        let passwordValid = !password.isEmpty && password.count >= 8
        
        // Coach code is optional, so we only validate it if it's not empty
        if !coachAccessCode.isEmpty {
            return isCoachCodeValid && emailValid && passwordValid
        }
        
        return emailValid && passwordValid
    }
    
    private func getPasswordStrengthColor(_ index: Int) -> Color {
        let strength = calculatePasswordStrength()
        if index < strength {
            return TailwindColors.violet400
        }
        return Color.gray.opacity(0.3)
    }
    
    private func calculatePasswordStrength() -> Int {
        var strength = 0
        if password.count >= 8 { strength += 1 }
        if password.contains(where: { $0.isNumber }) { strength += 1 }
        if password.contains(where: { $0.isUppercase }) { strength += 1 }
        if password.contains(where: { $0.isSpecialCharacter }) { strength += 1 }
        return strength
    }
    
    private func createAccount() {
        print("DEBUG: Starting account creation")
        
        // Clear any old role data from UserDefaults first to ensure a clean state
        UserDefaults.standard.removeObject(forKey: "userRole")
        UserDefaults.standard.removeObject(forKey: "lastAccessCode")
        
        // Only set coach data if valid code is provided
        let isCoach = coachAccessCode == validCoachCode
        
        if isCoach {
            UserDefaults.standard.set(coachAccessCode, forKey: "lastAccessCode")
            UserDefaults.standard.set("Coach", forKey: "userRole")
            print("DEBUG: Saved coach access code to UserDefaults")
        } else {
            // Explicitly set as student to override any previous settings
            UserDefaults.standard.set("Student", forKey: "userRole")
            print("DEBUG: Set role as Student in UserDefaults")
        }
        
        // Determine role string based solely on access code
        let roleString = isCoach ? "Coach" : "Student"
        
        print("DEBUG: Creating account with role: \(roleString)")
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("DEBUG: Error creating user: \(error)")
                self.alertMessage = error.localizedDescription
                self.showAlert = true
                return
            }
            
            guard let user = result?.user else {
                print("DEBUG: No user returned from createUser")
                return
            }
            
            print("DEBUG: User created successfully with ID: \(user.uid)")
            print("DEBUG: Using role: \(roleString)")
            
            // Store user role in Firestore
            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "email": self.email,
                "role": roleString,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            print("DEBUG: Setting user document with data: \(userData)")
            db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    print("DEBUG: Error setting user document: \(error)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    return
                }
                
                print("DEBUG: User document created successfully with role: \(roleString)")
                
                // Create a more straightforward flow without excessive nesting
                self.handleRoleAssignmentAndNavigation(user: user, isCoach: isCoach, roleString: roleString)
            }
        }
    }
    
    private func handleRoleAssignmentAndNavigation(user: User, isCoach: Bool, roleString: String) {
        print("DEBUG: Setting up role assignment for: \(roleString)")
        
        // Make absolutely sure the role is set in UserDefaults
        UserDefaults.standard.set(roleString, forKey: "userRole")
        UserDefaults.standard.synchronize() // Force immediate write
        print("DEBUG: Saved role to UserDefaults: \(roleString)")
        
        // For coaches, immediately navigate without waiting for anything else
        if isCoach {
            print("DEBUG: COACH CODE DETECTED - Forcing direct navigation to CoachMainView")
            DispatchQueue.main.async {
                // Force update auth model first
                self.authViewModel.forceUpdateRole(.coach)
                // Then navigate
                self.showCoachView = true
            }
            return // Skip all other processing for coaches
        }
        
        // For students, continue with normal flow
        DispatchQueue.main.async {
            // Make sure we explicitly set student role
            self.authViewModel.forceUpdateRole(.student)
            print("DEBUG: Force set role to STUDENT")
            
            // Navigate after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("DEBUG: Navigating to MainTabView")
                self.showMainTab = true
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
