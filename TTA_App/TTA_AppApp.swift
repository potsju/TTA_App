import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Configure AppCheck with debug provider for development
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        return true
    }
}

@main
struct TTA_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @State private var hasCheckedRole = false
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                Group {
                    // Use the authViewModel's role as the source of truth
                    switch authViewModel.userRole {
                    case .coach:
                        CoachMainView()
                            .environmentObject(authViewModel)
                            .transition(.opacity)
                            .onAppear {
                                print("DEBUG: Showing CoachMainView - Role is coach")
                            }
                    case .manager:
                        // Use a dedicated ManagerMainView for managers
                        ManagerMainView()
                            .environmentObject(authViewModel)
                            .transition(.opacity)
                            .onAppear {
                                print("DEBUG: Showing ManagerMainView - Role is manager")
                            }
                    case .student, .unknown:
                        MainTabView()
                            .environmentObject(authViewModel)
                            .transition(.opacity)
                            .onAppear {
                                print("DEBUG: Showing MainTabView - Role is student or unknown")
                            }
                    }
                }
                .animation(.easeInOut, value: authViewModel.userRole)
                .task {
                    if !hasCheckedRole {
                        if let userId = Auth.auth().currentUser?.uid {
                            // Let AuthViewModel handle the role check
                            authViewModel.checkUserRoleFromFirestore(userId: userId)
                        }
                        hasCheckedRole = true
                    }
                }
            } else {
                LoginView()
                    .environmentObject(authViewModel)
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
                    .onAppear {
                        // Reset the role check flag when going back to login
                        hasCheckedRole = false
                    }
            }
        }
    }
}
