import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ManagerMainView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var userName: String = "Manager"
    @State private var isLoading = true
    @State private var refreshID = UUID()
    @State private var subscriptions = Set<AnyCancellable>()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            ManagerDashboard()
                .id(refreshID)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)
            
            // Coaches Tab
            ManagerCoachesView()
                .tabItem {
                    Label("Coaches", systemImage: "person.3.fill")
                }
                .tag(1)
            
            // Students Tab
            ManagerStudentsView()
                .tabItem {
                    Label("Students", systemImage: "person.2.fill")
                }
                .tag(2)
            
            // Finances Tab
            ManagerFinancesView()
                .tabItem {
                    Label("Finances", systemImage: "dollarsign.circle.fill")
                }
                .tag(3)
           
        }
        .accentColor(TailwindColors.violet400)
        .onChange(of: selectedTab) { newTab in
            if newTab == 0 {
                refreshID = UUID()
            }
        }
        .onAppear {
            loadUserInfo()
        }
    }
    
    private func loadUserInfo() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("ERROR: Failed to load user info: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data(),
               let firstName = data["firstName"] as? String,
               let lastName = data["lastName"] as? String {
                DispatchQueue.main.async {
                    self.userName = "\(firstName) \(lastName)"
                    self.isLoading = false
                }
            } else {
                self.isLoading = false
            }
        }
    }
} 

#Preview {
    ManagerMainView()
        .environmentObject(MockAuthViewModel(role: .manager))
} 
