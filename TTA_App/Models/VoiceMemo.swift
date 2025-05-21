import SwiftUI
import FirebaseFirestore

struct VoiceMemo: Identifiable {
    let id: String
    let url: String
    let duration: TimeInterval
    let timestamp: Date
    let coachId: String
    let studentId: String
    let classId: String?
    let sessionReportId: String?
    let createdBy: String // "coach" or "student"
    
    // Convert Firestore document to VoiceMemo
    static func fromFirestore(document: DocumentSnapshot) -> VoiceMemo? {
        guard let data = document.data() else { return nil }
        
        return VoiceMemo(
            id: document.documentID,
            url: data["url"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 0,
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            coachId: data["coachId"] as? String ?? "",
            studentId: data["studentId"] as? String ?? "",
            classId: data["classId"] as? String,
            sessionReportId: data["sessionReportId"] as? String,
            createdBy: data["createdBy"] as? String ?? "coach"
        )
    }
    
    // Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "url": url,
            "duration": duration,
            "timestamp": Timestamp(date: timestamp),
            "coachId": coachId,
            "studentId": studentId,
            "createdBy": createdBy
        ]
        
        if let classId = classId {
            data["classId"] = classId
        }
        
        if let sessionReportId = sessionReportId {
            data["sessionReportId"] = sessionReportId
        }
        
        return data
    }
} 