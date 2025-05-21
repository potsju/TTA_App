import SwiftUI
import FirebaseAuth

struct LoginPageView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showPassword: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    private func signIn() {
        Auth.auth().signIn(withEmail: username, password: password) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                } else {
                    // The AuthViewModel will automatically update the isAuthenticated state
                    // through its auth state listener
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .resizable()
                    .frame(width: 12, height: 20)
                    .foregroundColor(TailwindColors.gray500)
                    .padding(16)
            }
            
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    // Logo
                    Image("TTALogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 117)
                        .padding(.top, 87)
                        .padding(.bottom, 13)
                    
                    // Form container
                    VStack(alignment: .leading, spacing: 0) {
                        // Login field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Login")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(TailwindColors.gray500)
                            TextField("", text: $username)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .frame(height: 48)
                                .padding(.horizontal, 16)
                                .background(Color.clear)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(TailwindColors.zinc700, lineWidth: 1)
                                )
                        }
                        .padding(.bottom, 16)
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(TailwindColors.gray500)
                            ZStack(alignment: .trailing) {
                                    if showPassword {
                                        TextField("", text: $password)
                                            .frame(height: 48)
                                            .padding(.horizontal, 16)
                                            .background(Color.clear)
                                            .cornerRadius(16)
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("", text: $password)
                                            .frame(height: 48)
                                            .padding(.horizontal, 16)
                                            .background(Color.clear)
                                            .cornerRadius(16)
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(TailwindColors.gray500)
                                    }
                                    .padding(.trailing, 16)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(TailwindColors.zinc700, lineWidth: 1)
                                )
                            
                        }
                        .padding(.bottom, 24)
                        
                        // Remember me and Forgot password
                        HStack {
                            Button(action: {
                                rememberMe.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(TailwindColors.zinc700, lineWidth: 1)
                                            .frame(width: 24, height: 24)
                                        if rememberMe {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(TailwindColors.gray500)
                                        }
                                    }
                                    Text("Remember me")
                                        .font(.system(size: 14))
                                        .tracking(0.5)
                                        .foregroundColor(TailwindColors.gray500)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                resetPassword()
                            }) {
                                Text("Forgot password")
                                    .font(.system(size: 14))
                                    .tracking(0.5)
                                    .foregroundColor(TailwindColors.gray500)
                            }
                        }
                        .padding(.bottom, 24)
                        
                        // Sign In button
                        Button(action: {
                            signIn()
                        }) {
                            Text("Sign In")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(TailwindColors.neutral950)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(TailwindColors.violet100)
                                .cornerRadius(999)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 999)
                                        .stroke(Color.white, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 327)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .edgesIgnoringSafeArea(.bottom)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func resetPassword() {
        if username.isEmpty {
            alertMessage = "Please enter your email address first"
            showAlert = true
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: username) { error in
            if let error = error {
                alertMessage = error.localizedDescription
            } else {
                alertMessage = "Password reset email sent. Please check your inbox."
            }
            showAlert = true
        }
    }
}

struct LoginPageView_Previews: PreviewProvider {
    static var previews: some View {
        LoginPageView()
            .environmentObject(AuthViewModel())
    }
}
