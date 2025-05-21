import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct StudentMainView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var userName: String = "Student"
    @State private var isLoading = true
    @State private var refreshID = UUID()
    @State private var subscriptions = Set<AnyCancellable>()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Calendar Classes Tab (Main View)
            StudentCalendarClassesView()
                .id(refreshID)
                .tabItem {
                    Label("Classes", systemImage: "calendar.badge.plus")
                }
                .tag(0)
            
            // Classes Tab
            ClassesView()
                .tabItem {
                    Label("My Schedule", systemImage: "calendar")
                }
                .tag(1)
            
            // Coaches Tab
            CoachesView3()
                .tabItem {
                    Label("Coaches", systemImage: "person.3")
                }
                .tag(2)
            
            // Payments Tab
            PaymentsView()
                .tabItem {
                    Label("Payments", systemImage: "creditcard.fill")
                }
                .tag(3)
            
            // Profile Tab
            StudentProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
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
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let firstName = data["firstName"] as? String,
               let lastName = data["lastName"] as? String {
                self.userName = "\(firstName) \(lastName)"
            }
            self.isLoading = false
        }
    }
}

// Placeholder views for tabs
struct ClassesView: View {
    var body: some View {
        NavigationView {
            Text("Classes View - Student can see their class schedule")
                .navigationTitle("My Classes")
        }
    }
}

struct CoachesView3: View {
    var body: some View {
        NavigationView {
            Text("Coaches View - Student can browse available coaches")
                .navigationTitle("Coaches")
        }
    }
}

struct PaymentsView: View {
    var body: some View {
        NavigationView {
            Text("Payments View - Student can see payment history and credits")
                .navigationTitle("Payments")
        }
    }
}

// Preview provider
struct StudentMainView_Previews: PreviewProvider {
    static var previews: some View {
        StudentMainView()
            .environmentObject(MockAuthViewModel(role: .student))
    }
} 
