import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Class: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let instructorName: String
    let classTime: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let studentId: String?
    let creditCost: Int
    let isAvailable: Bool
    let isFinished: Bool
    let createdBy: String?
    
    // Computed property for status display
    var status: String {
        if isAvailable {
            return "Available"
        } else if isFinished {
            return "Completed"
        } else {
            return "Booked"
        }
    }
    
    // Computed property to get just the date part (no time)
    var dateOnly: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
    
    // Format the date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    static func == (lhs: Class, rhs: Class) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case instructorName
        case classTime
        case date
        case startTime
        case endTime
        case studentId
        case creditCost
        case isAvailable
        case isFinished
        case createdBy
    }
    
    init(id: String = UUID().uuidString,
         instructorName: String,
         classTime: String,
         date: Date,
         startTime: Date,
         endTime: Date,
         studentId: String? = nil,
         creditCost: Int,
         isAvailable: Bool = true,
         isFinished: Bool = false,
         createdBy: String? = nil) {
        self.id = id
        self.instructorName = instructorName
        self.classTime = classTime
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.studentId = studentId
        self.creditCost = creditCost
        self.isAvailable = isAvailable
        self.isFinished = isFinished
        self.createdBy = createdBy ?? Auth.auth().currentUser?.uid
        
        // Print creation info for debugging
        print("DEBUG: Created Class object - ID: \(id)")
        print("DEBUG: Date: \(date) - \(self.formattedDate)")
        print("DEBUG: Time: \(classTime) - \(startTime) to \(endTime)")
    }
    
    // Helper to convert Firestore data to a Class object
    static func fromFirestore(document: DocumentSnapshot) -> Class? {
        guard let data = document.data() else { 
            print("DEBUG: No data in document \(document.documentID)")
            return nil 
        }
        
        // For debugging, print the raw data
        print("DEBUG: Raw class data from Firestore: \(data)")
        
        // Extract required fields with safe unwrapping
        guard let id = data["id"] as? String,
              let instructorName = data["instructorName"] as? String,
              let classTime = data["classTime"] as? String,
              let creditCost = data["creditCost"] as? Int else {
            print("DEBUG: Missing required fields in document \(document.documentID)")
            return nil
        }
        
        // Handle date fields carefully
        let date: Date
        let startTimeDate: Date
        let endTimeDate: Date
        
        // Try different ways to get the dates
        if let dateTimestamp = data["date"] as? Timestamp {
            date = dateTimestamp.dateValue()
        } else if let dateObject = data["date"] as? Date {
            date = dateObject
        } else {
            print("DEBUG: Invalid date format in document \(document.documentID)")
            return nil
        }
        
        if let startTimeTimestamp = data["startTime"] as? Timestamp {
            startTimeDate = startTimeTimestamp.dateValue()
        } else if let startTimeObject = data["startTime"] as? Date {
            startTimeDate = startTimeObject
        } else {
            print("DEBUG: Invalid startTime format in document \(document.documentID)")
            return nil
        }
        
        if let endTimeTimestamp = data["endTime"] as? Timestamp {
            endTimeDate = endTimeTimestamp.dateValue()
        } else if let endTimeObject = data["endTime"] as? Date {
            endTimeDate = endTimeObject
        } else {
            print("DEBUG: Invalid endTime format in document \(document.documentID)")
            return nil
        }
        
        // Extract optional fields
        let studentId = data["studentId"] as? String
        let isAvailable = data["isAvailable"] as? Bool ?? true
        let isFinished = data["isFinished"] as? Bool ?? false
        let createdBy = data["createdBy"] as? String
        
        let classObj = Class(
            id: id,
            instructorName: instructorName,
            classTime: classTime,
            date: date,
            startTime: startTimeDate,
            endTime: endTimeDate,
            studentId: studentId,
            creditCost: creditCost,
            isAvailable: isAvailable,
            isFinished: isFinished,
            createdBy: createdBy
        )
        
        print("DEBUG: Successfully parsed class \(id) for date \(classObj.formattedDate)")
        return classObj
    }
    
    // Helper to convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "instructorName": instructorName,
            "classTime": classTime,
            "date": date,
            "startTime": startTime,
            "endTime": endTime,
            "creditCost": creditCost,
            "isAvailable": isAvailable,
            "isFinished": isFinished,
            "createdBy": createdBy as Any,
            "studentId": studentId as Any,
            "timestamp": FieldValue.serverTimestamp()
        ]
    }
    
    // Debug description
    var debugDescription: String {
        return """
        Class ID: \(id)
        Instructor: \(instructorName)
        Date: \(formattedDate)
        Time: \(classTime)
        Status: \(status)
        Created By: \(createdBy ?? "unknown")
        """
    }
} 