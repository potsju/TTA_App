import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore
import FirebaseCore


enum UserRole {
    case student
    case coach
    case manager
    case unknown
}

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userRole: UserRole = .student // Default to student role
    private var roleCheckCompleted = false
    
    init() {
        setupAuthStateListener()
        if let currentUser = Auth.auth().currentUser {
            // Set user role to student by default
            self.userRole = .student
            UserDefaults.standard.set("Student", forKey: "userRole")
        }
    }
    
    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAuthenticated = user != nil
                self.currentUser = user
                
                if let user = user {
                    self.checkUserRoleFromFirestore(userId: user.uid)
                } else {
                    self.userRole = .unknown
                    self.roleCheckCompleted = false
                }
            }
        }
    }
    
    // Check user role from Firestore
    func checkUserRoleFromFirestore(userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists,
               let data = document.data(),
               let role = data["role"] as? String {
                print("DEBUG: Found role in Firestore: \(role)")
                
                DispatchQueue.main.async {
                    switch role {
                    case "Coach":
                        self.userRole = .coach
                        UserDefaults.standard.set("Coach", forKey: "userRole")
                    case "Manager":
                        self.userRole = .manager
                        UserDefaults.standard.set("Manager", forKey: "userRole")
                    default:
                        self.userRole = .student
                        UserDefaults.standard.set("Student", forKey: "userRole")
                    }
                }
            } else {
                // Default to student
                DispatchQueue.main.async {
                    self.userRole = .student
                    UserDefaults.standard.set("Student", forKey: "userRole")
                }
            }
        }
    }
    
    // Force update the user role
    func forceUpdateRole(_ role: UserRole) {
        print("DEBUG: Force updating role to: \(role)")
        
        // Update the published property directly
        DispatchQueue.main.async {
            self.userRole = role
        }
        
        // Also update UserDefaults and Firestore
        let roleString: String
        switch role {
        case .coach:
            roleString = "Coach"
        case .manager:
            roleString = "Manager"
        case .student:
            roleString = "Student"
        case .unknown:
            roleString = "Student" // Default to student for unknown
        }
        
        UserDefaults.standard.set(roleString, forKey: "userRole")
        print("DEBUG: Force set role in UserDefaults to: \(roleString)")
        
        // Update Firestore if user is signed in
        if let userId = Auth.auth().currentUser?.uid {
            updateFirebaseRole(userId: userId, role: roleString)
        }
    }
    
    // Update role in Firebase
    private func updateFirebaseRole(userId: String, role: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "role": role
        ]) { error in
            if let error = error {
                print("DEBUG: Could not update role in Firebase: \(error.localizedDescription)")
            } else {
                print("DEBUG: Successfully updated role in Firebase")
            }
        }
    }
    
    // Check if role matches any of the given roles
    func hasRole(_ roles: [UserRole]) -> Bool {
        return roles.contains(userRole)
    }
    
    // Sign in with Google
    func signInWithGoogle() {
        // Get the Google configuration from Firebase
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("ERROR: No root view controller found")
            return
        }
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("ERROR: Google sign in failed: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user, 
                  let idToken = user.idToken?.tokenString else {
                print("ERROR: Missing auth data from Google")
                return
            }
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken, 
                accessToken: user.accessToken.tokenString
            )
            
            // Sign in to Firebase with the Google credential
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("ERROR: Firebase sign in failed: \(error.localizedDescription)")
                    return
                }
                
                // Successfully signed in, now save user data
                if let firebaseUser = authResult?.user {
                    let db = Firestore.firestore()
                    
                    // Get user info from Google profile
                    let firstName = user.profile?.givenName ?? ""
                    let lastName = user.profile?.familyName ?? ""
                    let email = user.profile?.email ?? ""
                    
                    // Create or update user document in Firestore
                    db.collection("users").document(firebaseUser.uid).setData([
                        "firstName": firstName,
                        "lastName": lastName,
                        "email": email,
                        "role": "Student", // Always student by default
                        "lastLogin": FieldValue.serverTimestamp()
                    ], merge: true) { error in
                        if let error = error {
                            print("ERROR: Failed to save user data: \(error.localizedDescription)")
                        } else {
                            print("DEBUG: User data saved successfully")
                            
                            // Set role to student
                            DispatchQueue.main.async {
                                self.userRole = .student
                                UserDefaults.standard.set("Student", forKey: "userRole")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            isAuthenticated = false
            userRole = .unknown
            roleCheckCompleted = false
            
            // Clear the role from UserDefaults
            UserDefaults.standard.removeObject(forKey: "userRole")
            print("DEBUG: Cleared role from UserDefaults")
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
} 
