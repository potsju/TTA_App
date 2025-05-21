import SwiftUI
import Firebase
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showCreateAccount = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(.top, 50)
                
                Text("Welcome to TTA")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                // Email and Password fields
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isSigningIn)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .disabled(isSigningIn)
                
                // Sign in with Email button
                Button(action: {
                    signInWithEmail()
                }) {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In with Email")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .disabled(isSigningIn)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Sign in with Google button
                Button(action: {
                    authViewModel.signInWithGoogle()
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                        Text("Sign In with Google")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                }
                .disabled(isSigningIn)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Create Account button
                NavigationLink(destination: CreateAccountView()) {
                    Text("Create Account")
                        .foregroundColor(.blue)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func signInWithEmail() {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            alertMessage = "Please enter both email and password"
            showAlert = true
            return
        }
        
        isSigningIn = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isSigningIn = false
                
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    return
                }
                
                // User successfully signed in
                if let user = result?.user {
                    print("User signed in: \(user.uid)")
                    authViewModel.userRole = .student
                    UserDefaults.standard.set("Student", forKey: "userRole")
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(MockAuthViewModel(role: .unknown))
}
