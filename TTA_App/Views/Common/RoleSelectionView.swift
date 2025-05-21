import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RoleSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedRole: UserRole = .student
    @State private var coachAccessCode: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isCoachCodeValid = false
    
    enum UserRole: String, CaseIterable {
        case student = "Student"
        case coach = "Coach"
    }
    
    private let validCoachCode = "8888"
    
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
                    
                    // Role selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select Your Role")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(TailwindColors.neutral950)
                            .padding(.bottom, 24)
                        
                        // Role selection buttons
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Button(action: {
                                selectedRole = role
                            }) {
                                HStack {
                                    Text(role.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(selectedRole == role ? .white : TailwindColors.neutral950)
                                    
                                    Spacer()
                                    
                                    if selectedRole == role {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(selectedRole == role ? TailwindColors.violet600 : TailwindColors.violet50)
                                .cornerRadius(12)
                            }
                        }
                        
                        if selectedRole == .coach {
                            // Coach access code field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enter Coach Access Code")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                SecureField("Access Code", text: $coachAccessCode)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: coachAccessCode) { newValue in
                                        isCoachCodeValid = newValue == validCoachCode
                                    }
                                
                                if !coachAccessCode.isEmpty && !isCoachCodeValid {
                                    Text("Invalid access code")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.top, 20)
                        }
                        
                        // Continue button
                        Button(action: {
                            if selectedRole == .coach && !isCoachCodeValid {
                                alertMessage = "Please enter a valid coach access code"
                                showAlert = true
                                return
                            }
                            saveUserRole()
                        }) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(TailwindColors.violet600)
                                .cornerRadius(12)
                        }
                        .padding(.top, 24)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .background(Color.white)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func saveUserRole() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "email": user.email ?? "",
            "role": selectedRole.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(user.uid).setData(userData) { error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            // Role saved successfully, dismiss the view
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView()
            .environmentObject(AuthViewModel())
    }
} 