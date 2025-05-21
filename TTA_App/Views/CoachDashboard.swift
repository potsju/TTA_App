import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DashboardStatCard2: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }
}

struct CoachDashboard: View {
    @State private var userName: String = "Coach"
    @State private var isLoading = true
    @State private var totalCredits: Int = 0
    @State private var monthlyBookings: Int = 0
    @State private var recentTransactions: [RecentActivityItem] = []
    
    struct RecentActivityItem: Identifiable {
        let id: String
        let studentName: String
        let classTime: String
        let date: Date
        let amount: Int
        let type: String // "booking" or "completed"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text(userName)
                                .font(.system(size: 24, weight: .bold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Stats Cards
                    HStack(spacing: 16) {
                        // Credits card
                        DashboardStatCard2(
                            title: "Credits",
                            value: "\(totalCredits)",
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        
                        // Monthly bookings
                        DashboardStatCard2(
                            title: "Monthly Bookings",
                            value: "\(monthlyBookings)",
                            icon: "calendar.badge.clock",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Report Buttons
                    HStack {
                        NavigationLink(destination: MonthlyTransactionsView()) {
                            Text("Monthly Report")
                                .fontWeight(.bold)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        NavigationLink(destination: YearlyTransactionsView()) {
                            Text("Yearly Report")
                                .fontWeight(.bold)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    // Recent activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if recentTransactions.isEmpty {
                            Text("No recent activity")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(recentTransactions) { activity in
                                RecentActivityRow(activity: activity)
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                print("CoachDashboard appeared, loading fresh data")
                Task {
                    // Clean the data and reset the state
                    recentTransactions = []
                    totalCredits = 0
                    monthlyBookings = 0
                    isLoading = true
                    
                    // Load all the data fresh
                    await loadStatistics()
                    await loadActivityFeed()
                }
            }
            .refreshable {
                await loadStatistics()
                await loadActivityFeed()
            }
        }
    }
    
    private func refreshData() async {
        await loadDashboardDataAsync()
    }
    
    private func loadDashboardData() {
        isLoading = true
        recentTransactions = []
        
        Task {
            await loadDashboardDataAsync()
        }
    }
    
    private func loadDashboardDataAsync() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        do {
        // Load user info
            let userSnapshot = try await db.collection("users").document(userId).getDocument()
            
            if let data = userSnapshot.data(),
               let firstName = data["firstName"] as? String,
               let lastName = data["lastName"] as? String {
                await MainActor.run {
                    self.userName = "\(firstName) \(lastName)"
                }
            }
            
            // Load credits - First try the direct earnings document
            let earningsDocRef = db.collection("users").document(userId).collection("earnings").document("summary")
            let earningsSnapshot = try await earningsDocRef.getDocument()
            
            if let data = earningsSnapshot.data(),
                   let credits = data["totalCredits"] as? Int {
                await MainActor.run {
                    self.totalCredits = credits
                    print("DEBUG: Loaded \(credits) credits from earnings/summary")
                }
            } else {
                // Try coach earnings as fallback
                let coachEarningsRef = db.collection("coach_earnings").document(userId)
                let coachEarningsSnapshot = try await coachEarningsRef.getDocument()
                
                if let data = coachEarningsSnapshot.data(),
                   let totalEarnings = data["totalEarnings"] as? Int {
                    await MainActor.run {
                        self.totalCredits = totalEarnings
                        print("DEBUG: Loaded \(totalEarnings) credits from coach_earnings")
                    }
                } else {
                    print("DEBUG: No earnings found, defaulting to 0")
                    await MainActor.run {
                        self.totalCredits = 0
                    }
                }
                }
                
                // Get monthly bookings
                let now = Date()
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                
            // Query for both coachId and createdBy to ensure we get all bookings
            let group = DispatchGroup()
            var totalMonthlyBookings = 0
            
            // Check bookings with coachId - don't filter by bookedAt field directly
            group.enter()
            let coachIdQuery = db.collection("bookings")
                .whereField("coachId", isEqualTo: userId)
                
            coachIdQuery.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error getting bookings: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    // Filter by date manually to avoid Firestore index issues
                    let monthlyDocs = documents.filter { doc in
                        if let date = (doc.data()["bookedAt"] as? Timestamp)?.dateValue() {
                            return date > startOfMonth
                        } else if let date = (doc.data()["date"] as? Timestamp)?.dateValue() {
                            return date > startOfMonth
                        }
                        return false
                    }
                    totalMonthlyBookings += monthlyDocs.count
                    print("DEBUG: Found \(monthlyDocs.count) monthly bookings with coachId")
                }
            }
            
            // Also check bookings with createdBy - don't filter by bookedAt field directly
            group.enter()
            let createdByQuery = db.collection("bookings")
                .whereField("createdBy", isEqualTo: userId)
                
            createdByQuery.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error getting bookings by createdBy: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    // Filter by date manually and check if not already counted
                    var additionalCount = 0
                    for doc in documents {
                        let docId = doc.documentID
                        
                        // Skip if already counted
                        if let existingSnapshot = snapshot?.documents, existingSnapshot.contains(where: { $0.documentID == docId }) {
                            continue
                        }
                        
                        // Check date manually
                        let data = doc.data()
                        if let date = (data["bookedAt"] as? Timestamp)?.dateValue(), date > startOfMonth {
                            additionalCount += 1
                        } else if let date = (data["date"] as? Timestamp)?.dateValue(), date > startOfMonth {
                            additionalCount += 1
                        }
                    }
                    
                    totalMonthlyBookings += additionalCount
                    print("DEBUG: Found \(additionalCount) additional monthly bookings with createdBy")
                }
            }
            
            // Also check classes collection
            group.enter()
            let classesQuery = db.collection("classes")
                .whereField("createdBy", isEqualTo: userId)
                .whereField("isAvailable", isEqualTo: false)
            
            classesQuery.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error getting classes: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    // Filter by date manually
                    let monthlyDocs = documents.filter { doc in
                        if let date = (doc.data()["date"] as? Timestamp)?.dateValue() {
                            return date > startOfMonth
                        }
                        return false
                    }
                    
                    // Only count classes not already counted in bookings
                    var newClassCount = 0
                    for doc in monthlyDocs {
                        let classId = doc.documentID
                        let data = doc.data()
                        let bookingId = data["bookingId"] as? String
                        
                        // If this class has a booking ID, it might be counted already
                        if let bookingId = bookingId, snapshot?.documents.contains(where: { $0.documentID == bookingId }) == true {
                            continue
                        }
                        
                        newClassCount += 1
                    }
                    
                    totalMonthlyBookings += newClassCount
                    print("DEBUG: Found \(newClassCount) monthly bookings from classes collection")
                }
            }
            
            // When all queries are done, update the UI
            group.notify(queue: .main) {
                self.monthlyBookings = totalMonthlyBookings
                print("DEBUG: Updated monthly bookings count to \(totalMonthlyBookings)")
            }
        } catch {
            print("Error loading statistics: \(error)")
        }
    }
    
    private func loadActivityFeed() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // Show loading indicator
            await MainActor.run {
                self.isLoading = true
            }
            
            print("DEBUG: Starting to load activity feed for user ID: \(userId)")
            
            // First query: check bookings with standard fields
            var activityItems: [RecentActivityItem] = []
            
            // IMPORTANT: Don't filter by bookedAt since some records might use different field names
            let recentBookingsSnapshot = try await db.collection("bookings")
                .whereField("coachId", isEqualTo: userId)
                .limit(to: 20)
                .getDocuments()
                
            print("DEBUG: Found \(recentBookingsSnapshot.documents.count) bookings with coachId")
            
            for document in recentBookingsSnapshot.documents {
                let data = document.data()
                print("DEBUG: Processing booking document: \(document.documentID)")
                
                let classId = data["classId"] as? String ?? ""
                let studentId = data["studentId"] as? String ?? ""
                let classTime = data["classTime"] as? String ?? "Unknown Time"
                
                // Try different date field names
                let date: Date
                if let bookedAt = data["bookedAt"] as? Timestamp {
                    date = bookedAt.dateValue()
                } else if let dateField = data["date"] as? Timestamp {
                    date = dateField.dateValue()
                } else if let createdAt = data["createdAt"] as? Timestamp {
                    date = createdAt.dateValue()
                } else {
                    date = Date() // Default to current date if no date field found
                    print("DEBUG: No date field found in document \(document.documentID)")
                }
                
                // Try different field names for cost/credits
                let amount: Int
                if let cost = data["cost"] as? Double {
                    amount = Int(cost)
                } else if let credits = data["credits"] as? Double {
                    amount = Int(credits)
                } else if let cost = data["cost"] as? Int {
                    amount = Int(cost)
                } else if let credits = data["credits"] as? Int {
                    amount = Int(credits)
                } else if let costStr = data["cost"] as? String, let costDbl = Double(costStr) {
                    amount = Int(costDbl)
                } else if let creditsStr = data["credits"] as? String, let creditsDbl = Double(creditsStr) {
                    amount = Int(creditsDbl)
                } else if let creditCost = data["creditCost"] as? Int {
                    amount = creditCost
                } else {
                    amount = 0
                    print("DEBUG: No cost/credits field found in document \(document.documentID)")
                }
                
                // Get student name
                var studentName = "Unknown Student"
                do {
                    let studentSnapshot = try await db.collection("users").document(studentId).getDocument()
                    
                    if let studentData = studentSnapshot.data() {
                        let firstName = studentData["firstName"] as? String ?? ""
                        let lastName = studentData["lastName"] as? String ?? ""
                        if !firstName.isEmpty || !lastName.isEmpty {
                            studentName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                } catch {
                    print("DEBUG: Error fetching student data: \(error.localizedDescription)")
                }
                
                let activity = RecentActivityItem(
                    id: document.documentID,
                    studentName: studentName,
                    classTime: classTime,
                    date: date,
                    amount: amount,
                    type: "booking"
                )
                
                activityItems.append(activity)
                print("DEBUG: Added activity for student: \(studentName), class time: \(classTime), amount: \(amount)")
            }
            
            // Second query: check bookings with createdBy
            let createdBySnapshot = try await db.collection("bookings")
                .whereField("createdBy", isEqualTo: userId)
                .limit(to: 20)
                .getDocuments()
                
            print("DEBUG: Found \(createdBySnapshot.documents.count) bookings with createdBy")
            
            for document in createdBySnapshot.documents {
                // Skip if already added
                if activityItems.contains(where: { $0.id == document.documentID }) {
                    continue
                }
                
                print("DEBUG: Processing createdBy booking document: \(document.documentID)")
                let data = document.data()
                let classId = data["classId"] as? String ?? ""
                let studentId = data["studentId"] as? String ?? ""
                let classTime = data["classTime"] as? String ?? "Unknown Time"
                
                // Try different date field names
                let date: Date
                if let bookedAt = data["bookedAt"] as? Timestamp {
                    date = bookedAt.dateValue()
                } else if let dateField = data["date"] as? Timestamp {
                    date = dateField.dateValue()
                } else if let createdAt = data["createdAt"] as? Timestamp {
                    date = createdAt.dateValue()
                } else {
                    date = Date() // Default to current date if no date field found
                    print("DEBUG: No date field found in document \(document.documentID)")
                }
                
                // Try different field names for cost/credits
                let amount: Int
                if let cost = data["cost"] as? Double {
                    amount = Int(cost)
                } else if let credits = data["credits"] as? Double {
                    amount = Int(credits)
                } else if let cost = data["cost"] as? Int {
                    amount = cost
                } else if let credits = data["credits"] as? Int {
                    amount = credits
                } else if let costStr = data["cost"] as? String, let costDbl = Double(costStr) {
                    amount = Int(costDbl)
                } else if let creditsStr = data["credits"] as? String, let creditsDbl = Double(creditsStr) {
                    amount = Int(creditsDbl)
                } else if let creditCost = data["creditCost"] as? Int {
                    amount = creditCost
                } else {
                    amount = 0
                    print("DEBUG: No cost/credits field found in document \(document.documentID)")
                }
                
                // Get student name
                var studentName = "Unknown Student"
                do {
                    let studentSnapshot = try await db.collection("users").document(studentId).getDocument()
                    
                    if let studentData = studentSnapshot.data() {
                        let firstName = studentData["firstName"] as? String ?? ""
                        let lastName = studentData["lastName"] as? String ?? ""
                        if !firstName.isEmpty || !lastName.isEmpty {
                            studentName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                } catch {
                    print("DEBUG: Error fetching student data: \(error.localizedDescription)")
                }
                
                let activity = RecentActivityItem(
                    id: document.documentID,
                    studentName: studentName,
                    classTime: classTime,
                    date: date,
                    amount: amount,
                    type: "booking"
                )
                
                activityItems.append(activity)
                print("DEBUG: Added activity from createdBy query for student: \(studentName), class time: \(classTime), amount: \(amount)")
            }
            
            // Third query: also check classes collection for additional data
            let classesSnapshot = try await db.collection("classes")
                .whereField("createdBy", isEqualTo: userId)
                .whereField("isAvailable", isEqualTo: false)
                .limit(to: 20)
                .getDocuments()
                
            print("DEBUG: Found \(classesSnapshot.documents.count) classes with createdBy and not available")
            
            for document in classesSnapshot.documents {
                // Skip if we already have this class in our activities
                if activityItems.contains(where: { $0.id == document.documentID }) {
                    continue
                }
                
                print("DEBUG: Processing class document: \(document.documentID)")
                let data = document.data()
                let studentId = data["studentId"] as? String ?? ""
                let classTime = data["classTime"] as? String ?? "Unknown Time"
                
                // Try different date field names
                let date: Date
                if let dateField = data["date"] as? Timestamp {
                    date = dateField.dateValue()
                } else {
                    date = Date() // Default to current date if no date field found
                    print("DEBUG: No date field found in class document \(document.documentID)")
                }
                
                // Get the credit cost
                let amount: Int
                if let creditCost = data["creditCost"] as? Int {
                    amount = creditCost
                } else {
                    amount = 0
                    print("DEBUG: No creditCost field found in class document \(document.documentID)")
                }
                
                // Get student name
                var studentName = "Unknown Student"
                if !studentId.isEmpty {
                    do {
                        let studentSnapshot = try await db.collection("users").document(studentId).getDocument()
                        
                        if let studentData = studentSnapshot.data() {
                            let firstName = studentData["firstName"] as? String ?? ""
                            let lastName = studentData["lastName"] as? String ?? ""
                            if !firstName.isEmpty || !lastName.isEmpty {
                                studentName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    } catch {
                        print("DEBUG: Error fetching student data: \(error.localizedDescription)")
                    }
                }
                
                let activity = RecentActivityItem(
                    id: document.documentID,
                    studentName: studentName,
                    classTime: classTime,
                    date: date,
                    amount: amount,
                    type: "booking"
                )
                
                activityItems.append(activity)
                print("DEBUG: Added activity from classes collection for student: \(studentName), class time: \(classTime), amount: \(amount)")
            }
            
            // Sort and update on main thread
            await MainActor.run {
                self.recentTransactions = activityItems.sorted(by: { $0.date > $1.date })
                self.isLoading = false
                print("DEBUG: Final activity feed count: \(activityItems.count)")
            }
        } catch {
            print("ERROR: Failed to load activity feed: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadStatistics() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // 1. Try loading from earnings summary first (primary source)
            let earningsRef = db.collection("users").document(userId).collection("earnings").document("summary")
            let earningsSnapshot = try await earningsRef.getDocument()
            
            var foundCredits = false
            
            if let data = earningsSnapshot.data(),
               let credits = data["totalCredits"] as? Int {
                await MainActor.run {
                    self.totalCredits = credits
                    print("DEBUG: Loaded \(credits) credits from earnings/summary")
                }
                foundCredits = true
            } 
            
            // 2. Try coach earnings as fallback
            if !foundCredits {
                let coachEarningsRef = db.collection("coach_earnings").document(userId)
                let coachEarningsSnapshot = try await coachEarningsRef.getDocument()
                
                if let data = coachEarningsSnapshot.data(),
                   let totalEarnings = data["totalEarnings"] as? Int {
                    await MainActor.run {
                        self.totalCredits = totalEarnings
                        print("DEBUG: Loaded \(totalEarnings) credits from coach_earnings")
                    }
                    foundCredits = true
                }
            }
            
            // 3. If still not found, calculate from bookings collection
            if !foundCredits {
                print("DEBUG: No earnings found in standard locations, calculating from bookings")
                let bookingsQuery = db.collection("bookings")
                    .whereField("coachId", isEqualTo: userId)
                
                let bookingsSnapshot = try await bookingsQuery.getDocuments()
                var calculatedCredits = 0
                
                for document in bookingsSnapshot.documents {
                    let data = document.data()
                    
                    // Try different field names for credits
                    if let credits = data["credits"] as? Double {
                        calculatedCredits += Int(credits)
                    } else if let cost = data["cost"] as? Double {
                        calculatedCredits += Int(cost)
                    } else if let credits = data["credits"] as? Int {
                        calculatedCredits += credits
                    } else if let cost = data["cost"] as? Int {
                        calculatedCredits += cost
                    }
                }
                
                // Also check classes collection
                let classesQuery = db.collection("classes")
                    .whereField("createdBy", isEqualTo: userId)
                    .whereField("isAvailable", isEqualTo: false)
                
                let classesSnapshot = try await classesQuery.getDocuments()
                
                for document in classesSnapshot.documents {
                    let data = document.data()
                    
                    if let creditCost = data["creditCost"] as? Int {
                        calculatedCredits += creditCost
                    }
                }
                
                // Update the found total
                await MainActor.run {
                    self.totalCredits = calculatedCredits
                    print("DEBUG: Calculated \(calculatedCredits) credits from transactions")
                }
                
                // Try to save this back to the earnings summary for future use
                try? await earningsRef.setData([
                    "totalCredits": calculatedCredits,
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
            }
            
            // Get monthly bookings
            let now = Date()
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            
            // Query for both coachId and createdBy to ensure we get all bookings
            let group = DispatchGroup()
            var totalMonthlyBookings = 0
            
            // Check bookings with coachId - don't filter by bookedAt field directly
            group.enter()
            let coachIdQuery = db.collection("bookings")
                .whereField("coachId", isEqualTo: userId)
                
            coachIdQuery.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error getting bookings: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    // Filter by date manually to avoid Firestore index issues
                    let monthlyDocs = documents.filter { doc in
                        if let date = (doc.data()["bookedAt"] as? Timestamp)?.dateValue() {
                            return date > startOfMonth
                        } else if let date = (doc.data()["date"] as? Timestamp)?.dateValue() {
                            return date > startOfMonth
                        }
                        return false
                    }
                    totalMonthlyBookings += monthlyDocs.count
                    print("DEBUG: Found \(monthlyDocs.count) monthly bookings with coachId")
                }
            }
            
            // Also check bookings with createdBy - don't filter by bookedAt field directly
            group.enter()
            let createdByQuery = db.collection("bookings")
                .whereField("createdBy", isEqualTo: userId)
                
            createdByQuery.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error getting bookings by createdBy: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    // Filter by date manually and check if not already counted
                    var additionalCount = 0
                    for doc in documents {
                        let docId = doc.documentID
                        
                        // Skip if already counted
                        if let existingSnapshot = snapshot?.documents, existingSnapshot.contains(where: { $0.documentID == docId }) {
                            continue
                        }
                        
                        // Check date manually
                        let data = doc.data()
                        if let date = (data["bookedAt"] as? Timestamp)?.dateValue(), date > startOfMonth {
                            additionalCount += 1
                        } else if let date = (data["date"] as? Timestamp)?.dateValue(), date > startOfMonth {
                            additionalCount += 1
                        }
                    }
                    
                    totalMonthlyBookings += additionalCount
                    print("DEBUG: Found \(additionalCount) additional monthly bookings with createdBy")
                }
            }
            
            // Also check classes collection
            group.enter()
            let classesQuery = db.collection("classes")
                .whereField("createdBy", isEqualTo: userId)
                .whereField("isAvailable", isEqualTo: false)
            
            classesQuery.getDocuments { snapshot, error in
                defer { group.leave() }
                        
                        if let error = error {
                    print("Error getting classes: \(error)")
                            return
                }
                
                if let documents = snapshot?.documents {
                    // Filter by date manually
                    let monthlyDocs = documents.filter { doc in
                        if let date = (doc.data()["date"] as? Timestamp)?.dateValue() {
                            return date > startOfMonth
                        }
                        return false
                    }
                    
                    // Only count classes not already counted in bookings
                    var newClassCount = 0
                    for doc in monthlyDocs {
                        let classId = doc.documentID
                        let data = doc.data()
                        let bookingId = data["bookingId"] as? String
                        
                        // If this class has a booking ID, it might be counted already
                        if let bookingId = bookingId, snapshot?.documents.contains(where: { $0.documentID == bookingId }) == true {
                            continue
                        }
                        
                        newClassCount += 1
                    }
                    
                    totalMonthlyBookings += newClassCount
                    print("DEBUG: Found \(newClassCount) monthly bookings from classes collection")
                }
            }
            
            // When all queries are done, update the UI
            group.notify(queue: .main) {
                self.monthlyBookings = totalMonthlyBookings
                print("DEBUG: Updated monthly bookings count to \(totalMonthlyBookings)")
            }
        } catch {
            print("Error loading statistics: \(error)")
        }
    }
}

struct RecentActivityRow: View {
    let activity: CoachDashboard.RecentActivityItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(activity.type == "booking" ? "New Booking" : "Class Completed") with \(activity.studentName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Class Time: \(activity.classTime)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Text(activity.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("+\(activity.amount) credits")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(TailwindColors.green600)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal)
    }
}

struct CoachDashboard_Previews: PreviewProvider {
    static var previews: some View {
        CoachDashboard()
    }
} 
