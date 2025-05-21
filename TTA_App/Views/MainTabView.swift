import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingCreateClass = false
    @State private var isCoach = false
    @State private var isLoading = true
    @State private var selectedDate = Date()
    @State private var userName = ""
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                TabView(selection: $selectedTab) {
                    // Home Tab
                    if isCoach {
                        CoachCalendarClassesView()
                            .tabItem {
                                Image(systemName: "house.fill")
                                Text("Home")
                            }
                            .tag(0)
                    } else {
                        StudentCalendarClassesView()
                            .tabItem {
                                Image(systemName: "house.fill")
                                Text("Home")
                            }
                            .tag(0)
                    }
                    
                    // Classes Tab - only shown for coaches
                    if isCoach {
                        CoachesView()
                            .tabItem {
                                Image(systemName: "calendar")
                                Text("Classes")
                            }
                            .tag(1)
                    } else {
                        // Coaches Tab - for students
                        StudentCoachesView()
                            .tabItem {
                                Image(systemName: "person.2.fill")
                                Text("Coaches")
                            }
                            .tag(1)
                    }
                    
                    // Balance Tab
                    BalanceView()
                        .tabItem {
                            Image(systemName: "wallet.pass.fill")
                            Text("Balance")
                        }
                        .tag(isCoach ? 2 : 2)
                    
                    // Profile Tab
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.crop.circle")
                            Text("Profile")
                        }
                        .tag(isCoach ? 3 : 3)
                }
                .accentColor(TailwindColors.violet400)
            }
        }
        .task {
            await loadUserInfo()
        }
        .sheet(isPresented: $showingCreateClass) {
            CreateClassView(selectedDate: selectedDate, instructorName: userName)
        }
    }
    
    private func loadUserInfo() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                if let role = document.data()?["role"] as? String {
                    isCoach = role == "Coach"
                }
                
                if let firstName = document.data()?["firstName"] as? String,
                   let lastName = document.data()?["lastName"] as? String {
                    userName = "\(firstName) \(lastName)"
                }
            }
            
            isLoading = false
        } catch {
            print("Error loading user info: \(error)")
            isLoading = false
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 