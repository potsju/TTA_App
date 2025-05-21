import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
class ClassService: ObservableObject {
    var classes: [Class] = []
    var availableClasses: [Class] = []
    
    // Simple tracking of created classes for immediate display
    var recentlyCreatedClasses: [Class] = []
    
    private let db = Firestore.firestore()
    private let balanceService: BalanceService
    private let coachEarningsService: CoachEarningsService
    
    init(balanceService: BalanceService = BalanceService(), 
         coachEarningsService: CoachEarningsService = CoachEarningsService()) {
        self.balanceService = balanceService
        self.coachEarningsService = coachEarningsService
        
        // Set up Firebase listener for classes
        setupClassListener()
    }
    
    // MARK: - Firebase Listeners
    
    private func setupClassListener() {
        db.collection("classes").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else {
                print("Error fetching classes: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            print("DEBUG: Firebase listener received \(documents.count) classes")
            
            var allClasses: [Class] = []
            var availableOnly: [Class] = []
            
            for document in documents {
                if let classObj = Class.fromFirestore(document: document) {
                    allClasses.append(classObj)
                    
                    if classObj.isAvailable {
                        availableOnly.append(classObj)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.classes = allClasses
                self.availableClasses = availableOnly
                print("DEBUG: Updated classes: \(allClasses.count) total, \(availableOnly.count) available")
            }
        }
    }
    
    // MARK: - Class Creation
    
    func createClass(instructorName: String, classTime: String, date: Date, startTime: Date, endTime: Date, creditCost: Int) async throws {
        // Ensure we have a user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            print("ERROR: No user ID found")
            throw NSError(domain: "ClassService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        // Use the provided instructor name or fetch from UserDefaults if empty
        var finalInstructorName = instructorName.trimmingCharacters(in: .whitespacesAndNewlines)
        print("DEBUG: Initial instructor name: '\(finalInstructorName)'")
        
        // If name is empty or default, try to load from profile
        if finalInstructorName.isEmpty || finalInstructorName == "Coach" {
            // First try UserDefaults
            if let profileData = UserDefaults.standard.data(forKey: "userProfile") {
                do {
                    let userProfile = try JSONDecoder().decode(UserProfile.self, from: profileData)
                    finalInstructorName = "\(userProfile.firstName) \(userProfile.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                    print("DEBUG: Using instructor name from UserDefaults profile: '\(finalInstructorName)'")
                } catch {
                    print("ERROR: Failed to decode profile: \(error)")
                }
            }
            
            // If still empty, try Firestore directly
            if finalInstructorName.isEmpty || finalInstructorName == "Coach" {
                print("DEBUG: Attempting to load instructor name from Firestore")
                do {
                    let db = Firestore.firestore()
                    let document = try await db.collection("users").document(userId).getDocument()
                    
                    if let firstName = document.data()?["firstName"] as? String,
                       let lastName = document.data()?["lastName"] as? String {
                        finalInstructorName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        print("DEBUG: Loaded instructor name from Firestore: '\(finalInstructorName)'")
                    }
                } catch {
                    print("ERROR: Failed to load user profile from Firestore: \(error)")
                }
            }
        }
        
        // Final fallback if still empty
        if finalInstructorName.isEmpty {
            finalInstructorName = "Coach"
            print("DEBUG: Using fallback instructor name: '\(finalInstructorName)'")
        }
        
        print("DEBUG: Final instructor name for class creation: '\(finalInstructorName)'")
        
        // Generate a unique ID
        let classId = UUID().uuidString
        
        // Normalize the date - ensure we use the same date components from the provided date
        // but with the time components from startTime and endTime
        let calendar = Calendar.current
        
        // Extract date components from provided date (year, month, day)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        print("DEBUG: Date components: year=\(dateComponents.year ?? 0), month=\(dateComponents.month ?? 0), day=\(dateComponents.day ?? 0)")
        
        // Create normalized times
        var startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        startComponents.year = dateComponents.year
        startComponents.month = dateComponents.month
        startComponents.day = dateComponents.day
        
        var endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        endComponents.year = dateComponents.year
        endComponents.month = dateComponents.month
        endComponents.day = dateComponents.day
        
        let normalizedDate = calendar.date(from: dateComponents) ?? date
        let normalizedStart = calendar.date(from: startComponents) ?? startTime
        let normalizedEnd = calendar.date(from: endComponents) ?? endTime
        
        print("DEBUG: Normalized date: \(normalizedDate)")
        print("DEBUG: Start time: \(normalizedStart)")
        print("DEBUG: End time: \(normalizedEnd)")
        
        // Create the class object
        let newClass = Class(
            id: classId,
            instructorName: finalInstructorName,
            classTime: classTime,
            date: normalizedDate,
            startTime: normalizedStart,
            endTime: normalizedEnd,
            creditCost: creditCost,
            isAvailable: true,
            createdBy: userId
        )
        
        // First, add to our local array for immediate visibility
        DispatchQueue.main.async {
            // Add to full classes list if not already there
            if !self.classes.contains(where: { $0.id == classId }) {
                self.classes.append(newClass)
            }
            
            // Add to available classes if not already there
            if !self.availableClasses.contains(where: { $0.id == classId }) {
                self.availableClasses.append(newClass)
            }
            
            // Add to recently created for immediate display
            self.recentlyCreatedClasses.append(newClass)
            
            print("DEBUG: Added class to local arrays: \(newClass.debugDescription)")
        }
        
        // Then save to Firestore
        do {
            try await db.collection("classes").document(classId).setData(newClass.toFirestoreData())
            print("DEBUG: Successfully saved class to Firestore with ID: \(classId)")
        } catch {
            print("ERROR: Failed to save class to Firestore: \(error.localizedDescription)")
            // Don't remove from local arrays - we already added it for visibility
            throw error
        }
    }
    
    // MARK: - Class Loading
    
    func loadAllClasses() async {
        print("DEBUG: Loading all classes")
        
        do {
            let snapshot = try await db.collection("classes").getDocuments()
            print("DEBUG: Fetched \(snapshot.documents.count) classes from Firestore")
            
            var allClasses: [Class] = []
            var availableOnly: [Class] = []
            
            for document in snapshot.documents {
                if let classObj = Class.fromFirestore(document: document) {
                    allClasses.append(classObj)
                    
                    if classObj.isAvailable {
                        availableOnly.append(classObj)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.classes = allClasses
                self.availableClasses = availableOnly
                print("DEBUG: Updated classes: \(allClasses.count) total, \(availableOnly.count) available")
            }
        } catch {
            print("ERROR: Failed to load classes from Firestore: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Booking a Class
    
    func bookClass(_ classItem: Class) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ClassService", code: 101, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        guard classItem.isAvailable else {
            throw NSError(domain: "ClassService", code: 102, userInfo: [NSLocalizedDescriptionKey: "Class is not available"])
        }
        
        print("DEBUG: Booking class: \(classItem.id)")
        
        do {
            // Update the class in Firebase
            try await db.collection("classes").document(classItem.id).updateData([
                "isAvailable": false,
                "studentId": userId
            ])
            
            print("DEBUG: Updated class in Firestore to booked status")
            
            // Create a booking record
            let bookingData: [String: Any] = [
                "coachId": classItem.createdBy ?? "",
                "studentId": userId,
                "classId": classItem.id,
                "classTime": classItem.classTime,
                "credits": Double(classItem.creditCost),  // Add as credits
                "cost": Double(classItem.creditCost),     // Also add as cost for compatibility
                "bookedAt": FieldValue.serverTimestamp(),
                "date": Timestamp(date: classItem.date),  // Add date field explicitly
                "instructorName": classItem.instructorName,
                "createdBy": classItem.createdBy ?? "",   // Also include createdBy
                "status": "completed"
            ]
            
            try await db.collection("bookings").addDocument(data: bookingData)
            print("DEBUG: Created booking record in Firestore")
            
            // Also add student to coach's students collection
            if let createdBy = classItem.createdBy {
                let studentData: [String: Any] = [
                    "studentId": userId,
                    "classId": classItem.id,
                    "classTime": classItem.classTime,
                    "bookedAt": FieldValue.serverTimestamp()
                ]
                
                try await db.collection("users").document(createdBy).collection("students").document(userId).setData(studentData, merge: true)
                print("DEBUG: Added student to coach's students collection")
            }
            
            // Handle credits
            try await balanceService.deductCredits(amount: classItem.creditCost)
            
            // Directly update coach's earnings document - in addition to using the service
            if let createdBy = classItem.createdBy {
                try await coachEarningsService.addEarnings(
                    coachId: createdBy, 
                    amount: classItem.creditCost,
                    studentId: userId,
                    classId: classItem.id,
                    classTime: classItem.classTime
                )
                
                // Also update the coach's total credits directly
                let creditsRef = db.collection("users").document(createdBy).collection("earnings").document("summary")
                
                try await creditsRef.setData([
                    "totalCredits": FieldValue.increment(Int64(classItem.creditCost)),
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
                
                print("DEBUG: Updated coach's total credits directly")
            }
            
            // Update local arrays
            await MainActor.run {
                // Create a new booked class object
                let bookedClass = Class(
                    id: classItem.id,
                    instructorName: classItem.instructorName,
                    classTime: classItem.classTime,
                    date: classItem.date,
                    startTime: classItem.startTime,
                    endTime: classItem.endTime,
                    studentId: userId,
                    creditCost: classItem.creditCost,
                    isAvailable: false,
                    createdBy: classItem.createdBy
                )
                
                // Update in classes array
                if let index = self.classes.firstIndex(where: { $0.id == classItem.id }) {
                    self.classes[index] = bookedClass
                } else {
                    self.classes.append(bookedClass)
                }
                
                // Remove from available classes
                self.availableClasses.removeAll { $0.id == classItem.id }
                
                print("DEBUG: Updated local arrays for booked class")
                
                // Post notification to refresh dashboard
                NotificationCenter.default.post(name: Notification.Name.classBookingUpdated, object: nil)
                print("DEBUG: Posted class booking notification to refresh dashboard")
            }
        } catch {
            print("ERROR: Failed to book class: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Marking a Class as Finished
    
    func markClassAsFinished(_ classItem: Class) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ClassService", code: 101, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        // Only coaches or the class creator can mark a class as finished
        let isCoach = await checkIfUserIsCoach(userId: userId)
        if !isCoach && (classItem.createdBy != userId) {
            throw NSError(domain: "ClassService", code: 103, userInfo: [NSLocalizedDescriptionKey: "Only coaches can mark classes as finished"])
        }
        
        // Check if the class is booked and not already finished
        guard !classItem.isAvailable && !classItem.isFinished else {
            throw NSError(domain: "ClassService", code: 102, userInfo: [NSLocalizedDescriptionKey: "Class must be booked and not already finished"])
        }
        
        print("DEBUG: Marking class as finished: \(classItem.id)")
        
        do {
            // Update the class in Firebase
            try await db.collection("classes").document(classItem.id).updateData([
                "isFinished": true
            ])
            
            print("DEBUG: Updated class in Firestore to finished status")
            
            // Add credits to coach earnings if there's a creator
            if let createdBy = classItem.createdBy, let studentId = classItem.studentId {
                try await coachEarningsService.addEarnings(
                    coachId: createdBy,
                    amount: classItem.creditCost,
                    studentId: studentId,
                    classId: classItem.id,
                    classTime: classItem.classTime
                )
                
                print("DEBUG: Added \(classItem.creditCost) credits to coach \(createdBy) earnings")
            }
            
            // Update local arrays
            await MainActor.run {
                // Create a new finished class object
                let finishedClass = Class(
                    id: classItem.id,
                    instructorName: classItem.instructorName,
                    classTime: classItem.classTime,
                    date: classItem.date,
                    startTime: classItem.startTime,
                    endTime: classItem.endTime,
                    studentId: classItem.studentId,
                    creditCost: classItem.creditCost,
                    isAvailable: false,
                    isFinished: true,
                    createdBy: classItem.createdBy
                )
                
                // Update in classes array
                if let index = self.classes.firstIndex(where: { $0.id == classItem.id }) {
                    self.classes[index] = finishedClass
                } else {
                    self.classes.append(finishedClass)
                }
                
                print("DEBUG: Updated local arrays for finished class")
            }
        } catch {
            print("ERROR: Failed to mark class as finished: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Class Editing
    
    func updateClass(_ classItem: Class, newInstructorName: String? = nil, newClassTime: String? = nil, 
                    newStartTime: Date? = nil, newEndTime: Date? = nil, newCreditCost: Int? = nil) async throws {
        // Ensure we have a user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            print("ERROR ClassService: No user ID found for update")
            throw NSError(domain: "ClassService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        // Check if this class belongs to the user
        if let createdBy = classItem.createdBy {
            if createdBy != userId {
                print("ERROR ClassService: User \(userId) tried to edit class created by \(createdBy)")
                
                // Check if the user is a coach - coaches can edit any class
                let isCoach = await checkIfUserIsCoach(userId: userId)
                if !isCoach {
                    throw NSError(domain: "ClassService", code: 103, userInfo: [NSLocalizedDescriptionKey: "You can only edit your own classes"])
                } else {
                    print("DEBUG ClassService: User is a coach, allowing edit of other user's class")
                }
            } else {
                print("DEBUG ClassService: User is editing their own class")
            }
        } else {
            print("ERROR ClassService: Class has no createdBy field")
        }
        
        print("DEBUG ClassService: Updating class: \(classItem.id)")
        
        let calendar = Calendar.current
        
        // Prepare updated fields
        var updateData: [String: Any] = [:]
        
        // Handle instructor name - ensure it's not empty or default
        var finalInstructorName = newInstructorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        print("DEBUG ClassService: Initial new instructor name for update: '\(finalInstructorName ?? "nil")'")
        
        if let name = finalInstructorName, (name.isEmpty || name == "Coach") {
            // First try UserDefaults
            if let profileData = UserDefaults.standard.data(forKey: "userProfile") {
                do {
                    let userProfile = try JSONDecoder().decode(UserProfile.self, from: profileData)
                    finalInstructorName = "\(userProfile.firstName) \(userProfile.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                    print("DEBUG ClassService: Using instructor name from profile for update: '\(finalInstructorName!)'")
                } catch {
                    print("ERROR ClassService: Failed to decode profile for update: \(error)")
                }
            }
            
            // If still empty, try Firestore directly
            if finalInstructorName?.isEmpty == true || finalInstructorName == "Coach" {
                print("DEBUG ClassService: Attempting to load instructor name from Firestore for update")
                do {
                    let db = Firestore.firestore()
                    let document = try await db.collection("users").document(userId).getDocument()
                    
                    if let firstName = document.data()?["firstName"] as? String,
                       let lastName = document.data()?["lastName"] as? String {
                        finalInstructorName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        print("DEBUG ClassService: Loaded instructor name from Firestore for update: '\(finalInstructorName!)'")
                    }
                } catch {
                    print("ERROR ClassService: Failed to load user profile from Firestore for update: \(error)")
                }
            }
        }
        
        // Final fallback if we're trying to update with an empty name
        if finalInstructorName?.isEmpty == true && newInstructorName != nil {
            finalInstructorName = "Coach"
            print("DEBUG ClassService: Using fallback instructor name for update: '\(finalInstructorName!)'")
        }
        
        if let instructorName = finalInstructorName, !instructorName.isEmpty {
            print("DEBUG ClassService: Setting instructorName field to: '\(instructorName)'")
            updateData["instructorName"] = instructorName
        }
        
        if let newClassTime = newClassTime {
            updateData["classTime"] = newClassTime
        }
        
        if let newCreditCost = newCreditCost {
            updateData["creditCost"] = newCreditCost
        }
        
        // Handle time updates
        var updatedStartTime = classItem.startTime
        var updatedEndTime = classItem.endTime
        var needTimeUpdate = false
        
        if let newStartTime = newStartTime {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: classItem.date)
            var startComponents = calendar.dateComponents([.hour, .minute], from: newStartTime)
            startComponents.year = dateComponents.year
            startComponents.month = dateComponents.month
            startComponents.day = dateComponents.day
            
            if let normalizedStart = calendar.date(from: startComponents) {
                updatedStartTime = normalizedStart
                updateData["startTime"] = normalizedStart
                needTimeUpdate = true
            }
        }
        
        if let newEndTime = newEndTime {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: classItem.date)
            var endComponents = calendar.dateComponents([.hour, .minute], from: newEndTime)
            endComponents.year = dateComponents.year
            endComponents.month = dateComponents.month
            endComponents.day = dateComponents.day
            
            if let normalizedEnd = calendar.date(from: endComponents) {
                updatedEndTime = normalizedEnd
                updateData["endTime"] = normalizedEnd
                needTimeUpdate = true
            }
        }
        
        // Update class time string if either start or end time changed
        if needTimeUpdate {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            
            let timeString = "\(formatter.string(from: updatedStartTime)) - \(formatter.string(from: updatedEndTime))"
            updateData["classTime"] = timeString
        }
        
        if updateData.isEmpty {
            print("DEBUG: No changes to update")
            return
        }
        
        // Update the class in Firestore
        do {
            try await db.collection("classes").document(classItem.id).updateData(updateData)
            print("DEBUG: Successfully updated class in Firestore with ID: \(classItem.id)")
            
            // Create updated class object for local arrays
            let updatedClass = Class(
                id: classItem.id,
                instructorName: finalInstructorName ?? classItem.instructorName,
                classTime: needTimeUpdate ? (updateData["classTime"] as? String ?? classItem.classTime) : (newClassTime ?? classItem.classTime),
                date: classItem.date,
                startTime: updatedStartTime,
                endTime: updatedEndTime,
                studentId: classItem.studentId,
                creditCost: newCreditCost ?? classItem.creditCost,
                isAvailable: classItem.isAvailable,
                createdBy: classItem.createdBy
            )
            
            // Update local arrays
            await MainActor.run {
                // Update in classes array
                if let index = self.classes.firstIndex(where: { $0.id == classItem.id }) {
                    self.classes[index] = updatedClass
                }
                
                // Update in available classes if it's there
                if let index = self.availableClasses.firstIndex(where: { $0.id == classItem.id }) {
                    self.availableClasses[index] = updatedClass
                }
                
                // Update in recently created classes if it's there
                if let index = self.recentlyCreatedClasses.firstIndex(where: { $0.id == classItem.id }) {
                    self.recentlyCreatedClasses[index] = updatedClass
                }
            }
        } catch {
            print("ERROR: Failed to update class in Firestore: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Utility Methods
    
    func getClassesForDate(_ date: Date) -> [Class] {
        let calendar = Calendar.current
        
        // Get date-only components for the date we're looking for
        let targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let targetDate = calendar.date(from: targetComponents)!
        
        print("DEBUG: Filtering classes for date: \(targetDate)")
        
        // Include recently created classes first
        var result = recentlyCreatedClasses.filter { classItem in
            let classComponents = calendar.dateComponents([.year, .month, .day], from: classItem.date)
            let classDate = calendar.date(from: classComponents)!
            
            let isMatch = calendar.isDate(targetDate, inSameDayAs: classDate)
            print("DEBUG: Checking recent class \(classItem.id) - \(classDate) against \(targetDate): \(isMatch ? "MATCH" : "NO MATCH")")
            return isMatch
        }
        
        // Then check regular classes
        for classItem in classes {
            let classComponents = calendar.dateComponents([.year, .month, .day], from: classItem.date)
            let classDate = calendar.date(from: classComponents)!
            
            let isMatch = calendar.isDate(targetDate, inSameDayAs: classDate)
            print("DEBUG: Checking class \(classItem.id) - \(classDate) against \(targetDate): \(isMatch ? "MATCH" : "NO MATCH")")
            
            if isMatch && !result.contains(where: { $0.id == classItem.id }) {
                result.append(classItem)
            }
        }
        
        print("DEBUG: Found \(result.count) classes for date \(targetDate)")
        return result
    }
    
    func getAvailableClassesForDate(_ date: Date) -> [Class] {
        return getClassesForDate(date).filter { $0.isAvailable }
    }
    
    // Add the deleteClass method back
    func deleteClass(_ classItem: Class) async throws {
        print("DEBUG: Deleting class: \(classItem.id)")
        
        do {
            // Delete from Firestore
            try await db.collection("classes").document(classItem.id).delete()
            print("DEBUG: Successfully deleted class from Firestore")
            
            // Update local arrays
            await MainActor.run {
                // Remove from classes array
                self.classes.removeAll { $0.id == classItem.id }
                
                // Remove from available classes array if it's there
                self.availableClasses.removeAll { $0.id == classItem.id }
                
                // Remove from recently created classes if it's there
                self.recentlyCreatedClasses.removeAll { $0.id == classItem.id }
            }
        } catch {
            print("ERROR: Failed to delete class: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper method to check if user is a coach
    private func checkIfUserIsCoach(userId: String) async -> Bool {
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let role = document.data()?["role"] as? String, role == "Coach" {
                print("DEBUG ClassService: User \(userId) is a coach")
                return true
            } else {
                print("DEBUG ClassService: User \(userId) is not a coach")
                return false
            }
        } catch {
            print("ERROR ClassService: Failed to check if user is coach: \(error)")
            return false
        }
    }
} 
