import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Observation

struct Coach: Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let profileImage: String?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct CoachesView: View {
    @State private var classService = ClassService()
    @State private var coaches: [Coach] = []
    @State private var isLoading = true
    @State private var selectedCoach: Coach?
    @State private var showingCoachClasses = false
    @State private var showingCreateClass = false
    @State private var userName: String = ""
    @State private var alertMessage = ""
    @State private var showingBookAlert = false
    @State private var coachClasses: [Class] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Button {
                                showingCreateClass = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Create Class")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(TailwindColors.violet400)
                                .cornerRadius(10)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            
                            ForEach(coaches) { coach in
                                CoachCard(coach: coach)
                                    .onTapGesture {
                                        selectedCoach = coach
                                        showingCoachClasses = true
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Coaches")
            .sheet(isPresented: $showingCoachClasses) {
                if let coach = selectedCoach {
                    CoachClassesView(coach: coach)
                }
            }
            .sheet(isPresented: $showingCreateClass) {
                CreateClassView(
                    selectedDate: Date(), 
                    instructorName: userName.isEmpty ? "Coach" : userName,
                    onClassCreated: {
                        handleClassCreated()
                    }
                )
            }
            .task {
                await loadCoaches()
                await loadUserInfo()
            }
            .alert("Booking Status", isPresented: $showingBookAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCoaches() async {
        isLoading = true
        do {
            print("DEBUG: Starting to load coaches")
            let db = Firestore.firestore()
            let snapshot = try await db.collection("users").whereField("role", isEqualTo: "Coach").getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) coach documents")
            
            coaches = snapshot.documents.compactMap { document -> Coach? in
                print("DEBUG: Processing coach document: \(document.documentID)")
                guard let data = document.data() as? [String: Any] else {
                    print("DEBUG: Document data is not a dictionary")
                    return nil
                }
                
                print("DEBUG: Document data: \(data)")
                
                guard let firstName = data["firstName"] as? String,
                      let lastName = data["lastName"] as? String,
                      let email = data["email"] as? String,
                      let role = data["role"] as? String,
                      let profileImage = data["profileImage"] as? String? else {
                    print("DEBUG: Missing firstName, lastName, email, role, or profileImage in document")
                    return nil
                }
                
                print("DEBUG: Successfully created coach: \(firstName) \(lastName)")
                return Coach(
                    id: document.documentID,
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    role: role,
                    profileImage: profileImage
                )
            }
            
            print("DEBUG: Final coaches array count: \(coaches.count)")
        } catch {
            print("DEBUG: Error loading coaches: \(error)")
        }
        isLoading = false
    }
    
    private func loadUserInfo() async {
        print("DEBUG: Loading user info in CoachesView")
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                if let firstName = document.data()?["firstName"] as? String,
                   let lastName = document.data()?["lastName"] as? String {
                    await MainActor.run {
                        self.userName = "\(firstName) \(lastName)"
                        print("DEBUG: Set username to: \(self.userName)")
                    }
                }
            }
        } catch {
            print("ERROR: Failed to load user info: \(error.localizedDescription)")
        }
    }
    
    private func loadCoachClasses() async {
        isLoading = true
        
        guard let coach = selectedCoach else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            // First load all classes
            await classService.loadAllClasses()
            
            // Then filter for this coach's classes
            await MainActor.run {
                self.coachClasses = classService.classes.filter { $0.createdBy == coach.id }
                print("DEBUG: Loaded \(self.coachClasses.count) classes for coach \(coach.fullName)")
                isLoading = false
            }
        } catch {
            print("ERROR: Failed to load coach classes: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "Failed to load classes: \(error.localizedDescription)"
                showingBookAlert = true
                isLoading = false
            }
        }
    }
    
    private func handleClassCreated() {
        print("DEBUG: CoachesView - class created, refreshing view")
        
        // Show success notification
        DispatchQueue.main.async {
            alertMessage = "Class created successfully!"
            showingBookAlert = true
        }
        
        // Refresh coach data
        Task {
            await loadCoaches()
        }
    }
}

struct CoachCard: View {
    let coach: Coach
    
    var body: some View {
        HStack {
            // Coach avatar
            Circle()
                .fill(TailwindColors.violet400)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(coach.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Tennis Coach")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TailwindColors.zinc700, lineWidth: 1)
        )
    }
}

struct CoachClassesView: View {
    let coach: Coach
    @State private var classService = ClassService()
    @State private var balanceService = BalanceService()
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var classes: [Class] = []
    @State private var showingBookAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                } else if classes.isEmpty {
                    VStack {
                        Text("No classes available")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("This coach hasn't created any classes yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(classes) { classItem in
                                if classItem.isAvailable {
                                    CoachClassItemView(classItem: classItem, onBook: { classToBook in
                                        Task {
                                            await bookClass(classToBook)
                                        }
                                    })
                                } else {
                                    ClassItemView(
                                        instructorName: classItem.instructorName,
                                        classTime: classItem.classTime,
                                        creditCost: classItem.creditCost,
                                        startTime: classItem.startTime,
                                        endTime: classItem.endTime
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("\(coach.fullName)'s Classes")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .task {
                await loadCoachClasses()
            }
            .alert("Booking Status", isPresented: $showingBookAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCoachClasses() async {
        isLoading = true
        do {
            // Use Firestore directly since we need to filter by coach ID
            let db = Firestore.firestore()
            let snapshot = try await db.collection("classes")
                .whereField("createdBy", isEqualTo: coach.id)
                .getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) classes for coach \(coach.fullName)")
            
            var loadedClasses: [Class] = []
            for document in snapshot.documents {
                if let classItem = Class.fromFirestore(document: document) {
                    loadedClasses.append(classItem)
                    print("DEBUG: Added class: \(classItem.id) - \(classItem.formattedDate)")
                }
            }
            
            await MainActor.run {
                self.classes = loadedClasses
                print("DEBUG: Updated UI with \(loadedClasses.count) classes")
                self.isLoading = false
            }
        } catch {
            print("ERROR: Failed to load coach classes: \(error.localizedDescription)")
            await MainActor.run {
                self.alertMessage = "Failed to load classes: \(error.localizedDescription)"
                self.showingBookAlert = true
                self.isLoading = false
            }
        }
    }
    
    private func bookClass(_ classItem: Class) async {
        do {
            // Try to book the class first
            try await classService.bookClass(classItem)
            alertMessage = "Successfully booked class!"
            showingBookAlert = true
            
            // Refresh the classes after successful booking
            await loadCoachClasses()
        } catch let error as NSError {
            if error.domain == "BalanceService" && error.code == 101 {
                alertMessage = "Insufficient credits to book this class"
            } else {
                alertMessage = "Failed to book class: \(error.localizedDescription)"
            }
            showingBookAlert = true
        } catch {
            alertMessage = "Failed to book class: \(error.localizedDescription)"
            showingBookAlert = true
        }
    }
}

struct CoachClassItemView: View {
    let classItem: Class
    let onBook: (Class) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Instructor name and credit cost
                VStack(alignment: .leading) {
                    Text(classItem.instructorName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Text("\(classItem.creditCost) credits")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Class time and book button
                VStack(alignment: .trailing) {
                    Text(classItem.classTime)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Button(action: { onBook(classItem) }) {
                        Text("Book")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(TailwindColors.violet400)
                            .cornerRadius(8)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Text(classItem.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(classItem.startTime.formatted(date: .omitted, time: .shortened)) - \(classItem.endTime.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TailwindColors.zinc700, lineWidth: 1)
        )
    }
}

struct CoachesView_Previews: PreviewProvider {
    static var previews: some View {
        CoachesView()
    }
} 