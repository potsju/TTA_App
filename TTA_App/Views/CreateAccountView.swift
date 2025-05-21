import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct CreateAccountView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isCreatingAccount = false
    @State private var selectedRole: UserRole = .student
    @State private var coachCode = ""
    @State private var managerCode = ""
    @State private var showCoachView = false
    @State private var showManagerView = false
    
    // Secret codes - in a real app, these should be verified server-side
    private let validCoachCode = "1234"
    private let validManagerCode = "5678"
    
    var body: some View {
        ScrollView {
            VStack {
                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                
                // Form fields
                VStack(spacing: 15) {
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.words)
                    
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.words)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    // Role selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Type")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Select Role", selection: $selectedRole) {
                            Text("Student").tag(UserRole.student)
                            Text("Coach").tag(UserRole.coach)
                            Text("Manager").tag(UserRole.manager)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    .padding(.top, 10)
                    
                    // Coach code field (only shown if coach is selected)
                    if selectedRole == .coach {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Coach Access Code")
                                .font(.subheadline)
                                .padding(.horizontal)
                            
                            SecureField("Enter coach access code", text: $coachCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                        .padding(.top, 10)
                    }
                    
                    // Manager code field (only shown if manager is selected)
                    if selectedRole == .manager {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Manager Access Code")
                                .font(.subheadline)
                                .padding(.horizontal)
                            
                            SecureField("Enter manager access code", text: $managerCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.top, 20)
                
                // Create Account button
                Button(action: {
                    createAccount()
                }) {
                    if isCreatingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .disabled(isCreatingAccount)
                .padding(.horizontal)
                .padding(.top, 30)
                
                // Back to Login button
                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Login")
                        .foregroundColor(.blue)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarBackButtonHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func createAccount() {
        // Validation
        if firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty {
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        if password != confirmPassword {
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        // Validate coach code if coach role is selected
        if selectedRole == .coach && coachCode != validCoachCode {
            alertMessage = "Invalid coach access code"
            showAlert = true
            return
        }
        
        // Validate manager code if manager role is selected
        if selectedRole == .manager && managerCode != validManagerCode {
            alertMessage = "Invalid manager access code"
            showAlert = true
            return
        }
        
        // Show loading state
        isCreatingAccount = true
        
        // Create account with Firebase
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            // Handle the result on the main thread
            DispatchQueue.main.async {
                isCreatingAccount = false
                
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    return
                }
                
                if let user = result?.user {
                    // Determine role string
                    let roleString: String
                    switch selectedRole {
                    case .coach:
                        roleString = "Coach"
                    case .manager:
                        roleString = "Manager"
                    case .student, .unknown:
                        roleString = "Student"
                    }
                    
                    // Create user profile with correct field names
                    let db = Firestore.firestore()
                    let userData: [String: Any] = [
                        "firstName": firstName,
                        "lastName": lastName,
                        "email": email,
                        "role": roleString,
                        "createdAt": FieldValue.serverTimestamp()
                    ]
                    
                    db.collection("users").document(user.uid).setData(userData) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                alertMessage = "Error saving user data: \(error.localizedDescription)"
                                showAlert = true
                                return
                            }
                            
                            // Set user role based on selection
                            authViewModel.forceUpdateRole(selectedRole)
                            
                            // Return to login screen
                            dismiss()
                        }
                    }
                }
            }
        }
    }
} 