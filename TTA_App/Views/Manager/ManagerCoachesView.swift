import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ManagerCoachesView: View {
    @State private var coaches: [Coach] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCoach: Coach?
    @State private var showingCoachDetails = false
    @State private var showingAddCoach = false
    
    // Preview-only initializer
    init(previewData: [Coach]? = nil, isLoading: Bool = true) {
        if let previewData = previewData {
            _coaches = State(initialValue: previewData)
            _isLoading = State(initialValue: isLoading)
        }
    }
    
    struct Coach: Identifiable {
        let id: String
        let firstName: String
        let lastName: String
        let email: String
        let phoneNumber: String
        let profileImageURL: String?
        let totalEarnings: Int
        let totalHours: Double
        let activeStudents: Int
        
        var fullName: String {
            "\(firstName) \(lastName)"
        }
    }
    
    var filteredCoaches: [Coach] {
        if searchText.isEmpty {
            return coaches
        } else {
            return coaches.filter { coach in
                coach.firstName.lowercased().contains(searchText.lowercased()) ||
                coach.lastName.lowercased().contains(searchText.lowercased()) ||
                coach.email.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search coaches", text: $searchText)
                            .disableAutocorrection(true)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading coaches...")
                        Spacer()
                    } else if coaches.isEmpty {
                        Spacer()
                        VStack(spacing: 15) {
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 60))
                                .foregroundColor(TailwindColors.violet300)
                            
                            Text("No coaches found")
                                .font(.headline)
                            
                            Button(action: {
                                showingAddCoach = true
                            }) {
                                Text("Add a Coach")
                                    .padding()
                                    .background(TailwindColors.violet500)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredCoaches) { coach in
                                CoachRow(coach: coach)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedCoach = coach
                                        showingCoachDetails = true
                                    }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                // FAB for adding a coach
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddCoach = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(TailwindColors.violet500)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Coaches")
            .navigationBarItems(trailing: Button(action: {
                loadCoaches()
            }) {
                Image(systemName: "arrow.clockwise")
            })
            .onAppear {
                loadCoaches()
            }
            .sheet(isPresented: $showingCoachDetails) {
                if let coach = selectedCoach {
                    CoachDetailView(coach: coach)
                }
            }
            .sheet(isPresented: $showingAddCoach) {
                AddCoachView(onCoachAdded: {
                    loadCoaches()
                })
            }
        }
    }
    
    private func loadCoaches() {
        isLoading = true
        coaches = []
        
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("role", isEqualTo: "Coach")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading coaches: \(error)")
                    isLoading = false
                    return
                }
                
                let coachIDs = snapshot?.documents.compactMap { $0.documentID } ?? []
                var loadedCoaches: [Coach] = []
                let group = DispatchGroup()
                
                for coachID in coachIDs {
                    group.enter()
                    
                    // Load coach profile
                    db.collection("users").document(coachID).getDocument { snapshot, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("Error loading coach \(coachID): \(error)")
                            return
                        }
                        
                        guard let data = snapshot?.data(),
                              let firstName = data["firstName"] as? String,
                              let lastName = data["lastName"] as? String,
                              let email = data["email"] as? String else {
                            return
                        }
                        
                        let profileImageURL = data["profileImageURL"] as? String
                        let phoneNumber = data["phoneNumber"] as? String ?? "Not provided"
                        
                        // Calculate total earnings
                        group.enter()
                        db.collection("coach_earnings").document(coachID).getDocument { snapshot, error in
                            defer { group.leave() }
                            
                            var totalEarnings = 0
                            if let data = snapshot?.data(),
                               let earnings = data["totalEarnings"] as? Int {
                                totalEarnings = earnings
                            }
                            
                            // Get active students count
                            group.enter()
                            db.collection("classes")
                                .whereField("createdBy", isEqualTo: coachID)
                                .whereField("isAvailable", isEqualTo: false)
                                .getDocuments { snapshot, error in
                                    defer { group.leave() }
                                    
                                    let studentIDs = Set(snapshot?.documents.compactMap { 
                                        $0.data()["studentId"] as? String 
                                    } ?? [])
                                    
                                    let activeStudents = studentIDs.count
                                    
                                    // Calculate total hours
                                    group.enter()
                                    db.collection("classes")
                                        .whereField("createdBy", isEqualTo: coachID)
                                        .whereField("isAvailable", isEqualTo: false)
                                        .getDocuments { snapshot, error in
                                            defer { group.leave() }
                                            
                                            let totalHours = Double((snapshot?.documents.count ?? 0)) * 0.5 // Assuming 30min per class
                                            
                                            let coach = Coach(
                                                id: coachID,
                                                firstName: firstName,
                                                lastName: lastName,
                                                email: email,
                                                phoneNumber: phoneNumber,
                                                profileImageURL: profileImageURL,
                                                totalEarnings: totalEarnings,
                                                totalHours: totalHours,
                                                activeStudents: activeStudents
                                            )
                                            
                                            loadedCoaches.append(coach)
                                        }
                                }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self.coaches = loadedCoaches.sorted(by: { $0.lastName < $1.lastName })
                    self.isLoading = false
                }
            }
    }
}

struct CoachRow: View {
    let coach: ManagerCoachesView.Coach
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile image or initials
            ZStack {
                Circle()
                    .fill(TailwindColors.violet100)
                    .frame(width: 50, height: 50)
                
                Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(TailwindColors.violet600)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(coach.fullName)
                    .font(.headline)
                
                Text(coach.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(coach.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(coach.totalEarnings) credits")
                    .font(.subheadline)
                    .foregroundColor(TailwindColors.green600)
                
                Text("\(coach.activeStudents) students")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CoachDetailView: View {
    let coach: ManagerCoachesView.Coach
    @State private var isLoading = true
    @State private var coachClasses: [CoachClass] = []
    
    struct CoachClass: Identifiable {
        let id: String
        let studentName: String
        let date: Date
        let time: String
        let earnings: Int
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Coach header
                    VStack {
                        // Profile image or initials
                        ZStack {
                            Circle()
                                .fill(TailwindColors.violet100)
                                .frame(width: 100, height: 100)
                            
                            Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(TailwindColors.violet600)
                        }
                        
                        Text(coach.fullName)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 10)
                        
                        Text(coach.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            
                        Text(coach.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding()
                    
                    // Stats cards
                    HStack(spacing: 10) {
                        StatCard(title: "Total Earnings", value: "\(coach.totalEarnings)", suffix: "credits", icon: "dollarsign.circle.fill", color: .green)
                        StatCard(title: "Total Hours", value: String(format: "%.1f", coach.totalHours), suffix: "hrs", icon: "clock.fill", color: .blue)
                        StatCard(title: "Students", value: "\(coach.activeStudents)", icon: "person.2.fill", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // Recent classes
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Classes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if coachClasses.isEmpty {
                            Text("No classes found")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(coachClasses) { coachClass in
                                ClassRow(coachClass: coachClass)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Coach Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                // This sheet will be dismissed by the presentationMode
            })
            .onAppear {
                loadCoachClasses()
            }
        }
    }
    
    private func loadCoachClasses() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("classes")
            .whereField("createdBy", isEqualTo: coach.id)
            .whereField("isAvailable", isEqualTo: false)
            .order(by: "date", descending: true)
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading coach classes: \(error)")
                    isLoading = false
                    return
                }
                
                let classes = snapshot?.documents.compactMap { document -> CoachClass? in
                    let data = document.data()
                    guard let studentName = data["studentName"] as? String,
                          let timestamp = data["date"] as? Timestamp,
                          let time = data["classTime"] as? String else {
                        return nil
                    }
                    
                    let earnings = data["credits"] as? Int ?? data["cost"] as? Int ?? 10
                    
                    return CoachClass(
                        id: document.documentID,
                        studentName: studentName,
                        date: timestamp.dateValue(),
                        time: time,
                        earnings: earnings
                    )
                } ?? []
                
                DispatchQueue.main.async {
                    self.coachClasses = classes
                    self.isLoading = false
                }
            }
    }
}

struct ClassRow: View {
    let coachClass: CoachDetailView.CoachClass
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(coachClass.studentName)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(coachClass.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                    
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(coachClass.time)
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(coachClass.earnings) credits")
                .fontWeight(.bold)
                .foregroundColor(TailwindColors.green600)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var suffix: String = ""
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct AddCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var onCoachAdded: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Coach Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    SecureField("Password", text: $password)
                }
                
                Section {
                    Button(action: createCoach) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create Coach Account")
                        }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || email.isEmpty || phoneNumber.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle("Add Coach")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func createCoach() {
        isLoading = true
        
        // Create user account
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isLoading = false
                }
                return
            }
            
            guard let userId = result?.user.uid else {
                DispatchQueue.main.async {
                    alertMessage = "Error creating user account"
                    showAlert = true
                    isLoading = false
                }
                return
            }
            
            // Add user profile to database
            let db = Firestore.firestore()
            db.collection("users").document(userId).setData([
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "phoneNumber": phoneNumber,
                "role": "Coach",
                "createdAt": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        alertMessage = "Error saving user data: \(error.localizedDescription)"
                        showAlert = true
                        isLoading = false
                        return
                    }
                    
                    // Initialize earnings document
                    db.collection("coach_earnings").document(userId).setData([
                        "totalEarnings": 0
                    ]) { error in
                        DispatchQueue.main.async {
                            isLoading = false
                            
                            if let error = error {
                                alertMessage = "Error initializing earnings: \(error.localizedDescription)"
                                showAlert = true
                                return
                            }
                            
                            // Success - dismiss and refresh
                            onCoachAdded()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct AddCoachView_Previews: PreviewProvider {
    static var previews: some View {
        AddCoachView(onCoachAdded: {})
            .environmentObject(MockAuthViewModel(role: .manager))
    }
}

struct ManagerCoachesView_Previews: PreviewProvider {
    static var previews: some View {
        ManagerCoachesView(
            previewData: MockData.coaches,
            isLoading: false
        )
        .environmentObject(MockAuthViewModel(role: .manager))
    }
} 
