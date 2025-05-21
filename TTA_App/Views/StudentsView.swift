import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StudentsView: View {
    @State private var students: [Student] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedStudent: Student?
    @State private var showingStudentDetails = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading students...")
                } else if students.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(TailwindColors.violet400)
                            .padding(.bottom, 12)
                        
                        Text("No students yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Students who book your classes will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 40)
                } else {
                    List(students) { student in
                        Button(action: {
                            selectedStudent = student
                            showingStudentDetails = true
                        }) {
                            StudentCard(student: student)
                        }
                    }
                }
            }
            .navigationTitle("My Students")
            .sheet(isPresented: $showingStudentDetails) {
                if let student = selectedStudent {
                    EnhancedStudentDetailView(student: student)
                }
            }
        }
        .onAppear {
            print("StudentsView appeared, loading fresh data")
            loadStudents()
        }
        .refreshable {
            print("StudentsView refreshed by user")
            await loadStudentsAsync()
        }
    }
    
    private func loadStudents() {
        isLoading = true
        students = []
        
        Task {
            await loadStudentsAsync()
        }
    }
    
    private func loadStudentsAsync() async {
        guard let coachId = Auth.auth().currentUser?.uid else { 
            await MainActor.run {
                isLoading = false
            }
            return 
        }
        
        do {
            let db = Firestore.firestore()
            
            // Get all bookings for this coach
            let bookingsSnapshot = try await db.collection("bookings")
                .whereField("coachId", isEqualTo: coachId)
                .getDocuments()
            
            print("Found \(bookingsSnapshot.documents.count) bookings")
            
            // Get unique student IDs from bookings
            let studentIds = Set(bookingsSnapshot.documents.compactMap { $0.data()["studentId"] as? String })
            print("Found \(studentIds.count) unique student IDs")
            
            if studentIds.isEmpty {
                // Also check classes table as fallback
                let classesSnapshot = try await db.collection("classes")
                    .whereField("createdBy", isEqualTo: coachId)
                    .whereField("isAvailable", isEqualTo: false)
                    .getDocuments()
                
                let classStudentIds = Set(classesSnapshot.documents.compactMap { 
                    let studentId = $0.data()["studentId"] as? String
                    // Make sure it's not empty
                    return studentId != nil && !studentId!.isEmpty ? studentId : nil 
                })
                
                print("Found \(classStudentIds.count) student IDs from classes")
                
                // Combine with student IDs from bookings if any found
                let allStudentIds = studentIds.union(classStudentIds)
                
                if allStudentIds.isEmpty {
                    await MainActor.run {
                        students = []
                        isLoading = false
                    }
                    return
                }
                
                // Fetch student details
                var fetchedStudents: [Student] = []
                for studentId in allStudentIds {
                    let studentDoc = try await db.collection("users").document(studentId).getDocument()
                    if let studentData = studentDoc.data(),
                       let firstName = studentData["firstName"] as? String,
                       let lastName = studentData["lastName"] as? String,
                       let email = studentData["email"] as? String {
                        
                        // Fetch classes booked by this student with this coach
                        let classesSnapshot = try await db.collection("classes")
                            .whereField("createdBy", isEqualTo: coachId)
                            .whereField("studentId", isEqualTo: studentId)
                            .whereField("isAvailable", isEqualTo: false)
                            .getDocuments()
                        
                        var bookedClassesList: [ClassBookingInfo] = []
                        for document in classesSnapshot.documents {
                            if let classObj = Class.fromFirestore(document: document) {
                                let bookingInfo = ClassBookingInfo(
                                    classId: classObj.id,
                                    time: classObj.classTime,
                                    date: classObj.formattedDate,
                                    isFinished: classObj.isFinished
                                )
                                bookedClassesList.append(bookingInfo)
                            }
                        }
                        
                        // Create student with booked classes
                        let student = Student(
                            id: studentId,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            profileImage: studentData["profileImage"] as? String,
                            bookedClasses: bookedClassesList
                        )
                        fetchedStudents.append(student)
                        print("Added student: \(student.fullName) with \(bookedClassesList.count) booked classes")
                    }
                }
                
                await MainActor.run {
                    students = fetchedStudents.sorted { $0.fullName < $1.fullName }
                    isLoading = false
                    print("Total students loaded: \(students.count)")
                }
            } else {
                // Fetch student details
                var fetchedStudents: [Student] = []
                for studentId in studentIds {
                    let studentDoc = try await db.collection("users").document(studentId).getDocument()
                    if let studentData = studentDoc.data(),
                       let firstName = studentData["firstName"] as? String,
                       let lastName = studentData["lastName"] as? String,
                       let email = studentData["email"] as? String {
                        
                        // Also fetch classes booked by this student with this coach
                        let classesSnapshot = try await db.collection("classes")
                            .whereField("createdBy", isEqualTo: coachId)
                            .whereField("studentId", isEqualTo: studentId)
                            .whereField("isAvailable", isEqualTo: false)
                            .getDocuments()
                        
                        var bookedClassesList: [ClassBookingInfo] = []
                        for document in classesSnapshot.documents {
                            if let classObj = Class.fromFirestore(document: document) {
                                let bookingInfo = ClassBookingInfo(
                                    classId: classObj.id,
                                    time: classObj.classTime,
                                    date: classObj.formattedDate,
                                    isFinished: classObj.isFinished
                                )
                                bookedClassesList.append(bookingInfo)
                            }
                        }
                        
                        // Create student with booked classes
                        let student = Student(
                            id: studentId,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            profileImage: studentData["profileImage"] as? String,
                            bookedClasses: bookedClassesList
                        )
                        fetchedStudents.append(student)
                        print("Added student: \(student.fullName) with \(bookedClassesList.count) booked classes")
                    }
                }
                
                await MainActor.run {
                    students = fetchedStudents.sorted { $0.fullName < $1.fullName }
                    isLoading = false
                    print("Total students loaded: \(students.count)")
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                print("Error loading students: \(error.localizedDescription)")
            }
        }
    }
}

func bookClass(for studentId: String, classId: String, classTime: String, cost: Double) {
    guard let userId = Auth.auth().currentUser?.uid else { return }
    
    let db = Firestore.firestore()
    
    // Create a booking document
    let bookingData: [String: Any] = [
        "coachId": userId,
        "studentId": studentId,
        "classId": classId,
        "classTime": classTime,
        "cost": cost,
        "bookedAt": Timestamp(date: Date())
    ]
    
    db.collection("bookings").addDocument(data: bookingData) { error in
        if let error = error {
            print("Error booking class: \(error)")
            return
        }
        
        // Update coach's total credits
        let creditsRef = db.collection("users").document(userId).collection("earnings").document("summary")
        
        creditsRef.updateData([
            "totalCredits": FieldValue.increment(Int64(cost)) // Increment credits by the cost of the class
        ]) { error in
            if let error = error {
                print("Error updating credits: \(error)")
            } else {
                print("Credits updated successfully.")
            }
        }
        
        // Add the student to the coach's students list
        let studentData: [String: Any] = [
            "studentId": studentId,
            "classId": classId,
            "classTime": classTime,
            "bookedAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(userId).collection("students").document(studentId).setData(studentData) { error in
            if let error = error {
                print("Error adding student: \(error)")
            } else {
                print("Student added successfully.")
            }
        }
    }
} 