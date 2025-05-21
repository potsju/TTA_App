import SwiftUI

struct DashboardView: View {
    var body: some View {
        TabView {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
            
            // Remove the Classes Tab
            /*
            ClassesView()
                .tabItem {
                    Label("Classes", systemImage: "book")
                }
            */
            
            // Other tabs...
        }
    }
}

// For iOS 17+ (Xcode 15+)
#if compiler(>=5.9)
#Preview {
    DashboardView()
}
#else
// For iOS 16 and earlier
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
#endif 