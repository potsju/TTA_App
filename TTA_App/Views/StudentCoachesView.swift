import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct StudentCoachesView: View {
    @State private var coaches: [Coach] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedCoach: Coach?
    @State private var showingCoachDetails = false
    
    struct Coach: Identifiable {
        let id: String
        let firstName: String
        let lastName: String
        let profileImage: String?
        var classCount: Int = 0
        
        var fullName: String {
            "\(firstName) \(lastName)"
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading coaches...")
                } else if coaches.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(TailwindColors.violet400)
                            .padding(.bottom, 12)
                        
                        Text("No coaches yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Book a class to connect with coaches")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 40)
                } else {
                    List(coaches) { coach in
                        Button(action: {
                            selectedCoach = coach
                            showingCoachDetails = true
                        }) {
                            CoachCard2(coach: coach)
                        }
                    }
                }
            }
            .navigationTitle("My Coaches")
            .sheet(isPresented: $showingCoachDetails) {
                if let coach = selectedCoach {
                    CoachDetailView2(coach: coach)
                }
            }
        }
        .onAppear {
            loadCoaches()
        }
        .refreshable {
            await loadCoachesAsync()
        }
    }
    
    private func loadCoaches() {
        isLoading = true
        coaches = []
        
        Task {
            await loadCoachesAsync()
        }
    }
    
    private func loadCoachesAsync() async {
        guard let studentId = Auth.auth().currentUser?.uid else { 
            await MainActor.run {
                isLoading = false
            }
            return 
        }
        
        do {
            let db = Firestore.firestore()
            
            // Find all classes booked by this student
            let classesSnapshot = try await db.collection("classes")
                .whereField("studentId", isEqualTo: studentId)
                .whereField("isAvailable", isEqualTo: false)
                .getDocuments()
            
            // Extract unique coach IDs
            var coachMap: [String: (count: Int, classIds: [String])] = [:]
            
            for document in classesSnapshot.documents {
                if let createdBy = document.data()["createdBy"] as? String, !createdBy.isEmpty {
                    coachMap[createdBy, default: (0, [])].count += 1
                    coachMap[createdBy]!.classIds.append(document.documentID)
                }
            }
            
            // Get coach profiles
            var fetchedCoaches: [Coach] = []
            for (coachId, classInfo) in coachMap {
                let coachDoc = try await db.collection("users").document(coachId).getDocument()
                
                if let data = coachDoc.data(),
                   let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String {
                    
                    var coach = Coach(
                        id: coachId,
                        firstName: firstName,
                        lastName: lastName,
                        profileImage: data["profileImageURL"] as? String
                    )
                    coach.classCount = classInfo.count
                    fetchedCoaches.append(coach)
                }
            }
            
            await MainActor.run {
                coaches = fetchedCoaches.sorted { $0.fullName < $1.fullName }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct CoachCard2: View {
    let coach: StudentCoachesView.Coach
    
    var body: some View {
        HStack(spacing: 16) {
            // Coach avatar
            if let profileImage = coach.profileImage {
                AsyncImage(url: URL(string: profileImage)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(TailwindColors.violet100)
                        .overlay(
                            Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(TailwindColors.violet600)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(TailwindColors.violet100)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(TailwindColors.violet600)
                    )
            }
            
            // Coach info
            VStack(alignment: .leading, spacing: 4) {
                Text(coach.fullName)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("\(coach.classCount) \(coach.classCount == 1 ? "class" : "classes") booked")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

struct CoachDetailView2: View {
    let coach: StudentCoachesView.Coach
    @Environment(\.dismiss) var dismiss
    @State private var bookedClasses: [CoachClass] = []
    @State private var comments: [CoachComment] = []
    @State private var voiceMemos: [CoachVoiceMemo] = []
    @State private var isLoading = true
    
    struct CoachClass: Identifiable {
        let id: String
        let classTime: String
        let date: Date
        let isFinished: Bool
    }
    
    struct CoachComment: Identifiable {
        let id: String
        let text: String
        let timestamp: Date
        let classId: String?
        let className: String?
    }
    
    struct CoachVoiceMemo: Identifiable {
        let id: String
        let url: String
        let timestamp: Date
        let classId: String?
        let className: String?
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Coach Profile Header
                    VStack(spacing: 12) {
                        if let profileImage = coach.profileImage {
                            AsyncImage(url: URL(string: profileImage)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(TailwindColors.violet400)
                                    .overlay(
                                        Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(TailwindColors.violet400)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Text(coach.firstName.prefix(1) + coach.lastName.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        Text(coach.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(coach.classCount) \(coach.classCount == 1 ? "class" : "classes") booked")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    if isLoading {
                        ProgressView("Loading details...")
                            .padding()
                    } else {
                        // Booked Classes Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Booked Classes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if bookedClasses.isEmpty {
                                Text("No classes booked with this coach")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(bookedClasses) { classItem in
                                    ClassCard(classItem: classItem)
                                }
                            }
                        }
                        
                        // Comments Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coach Notes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if comments.isEmpty {
                                Text("No notes from this coach yet")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(comments) { comment in
                                    CoachCommentCard(comment: comment)
                                }
                            }
                        }
                        
                        // Voice Memos Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voice Memos")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if voiceMemos.isEmpty {
                                Text("No voice memos from this coach yet")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(voiceMemos) { memo in
                                    CoachVoiceMemoCard(memo: memo)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Coach Details")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .task {
                await loadCoachData()
            }
        }
    }
    
    private func loadCoachData() async {
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            guard let studentId = Auth.auth().currentUser?.uid else { return }
            
            // Load booked classes
            let classesSnapshot = try await db.collection("classes")
                .whereField("createdBy", isEqualTo: coach.id)
                .whereField("studentId", isEqualTo: studentId)
                .getDocuments()
            
            var loadedClasses: [CoachClass] = []
            var classIdToName: [String: String] = [:]
            
            for document in classesSnapshot.documents {
                let data = document.data()
                let isFinished = data["isFinished"] as? Bool ?? false
                let classTime = data["classTime"] as? String ?? "Unknown Time"
                let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                
                let classObj = CoachClass(
                    id: document.documentID,
                    classTime: classTime,
                    date: date,
                    isFinished: isFinished
                )
                
                loadedClasses.append(classObj)
                classIdToName[document.documentID] = classTime
            }
            
            // Load comments
            let commentsSnapshot = try await db.collection("student_comments")
                .whereField("studentId", isEqualTo: studentId)
                .whereField("coachId", isEqualTo: coach.id)
                .getDocuments()
            
            var loadedComments: [CoachComment] = []
            
            for document in commentsSnapshot.documents {
                let data = document.data()
                let text = data["text"] as? String ?? ""
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let classId = data["classId"] as? String
                let className = classId != nil ? classIdToName[classId!] : nil
                
                let comment = CoachComment(
                    id: document.documentID,
                    text: text,
                    timestamp: timestamp,
                    classId: classId,
                    className: className
                )
                
                loadedComments.append(comment)
            }
            
            // Load voice memos
            let memosSnapshot = try await db.collection("voice_memos")
                .whereField("studentId", isEqualTo: studentId)
                .whereField("coachId", isEqualTo: coach.id)
                .getDocuments()
            
            var loadedMemos: [CoachVoiceMemo] = []
            
            for document in memosSnapshot.documents {
                let data = document.data()
                let url = data["url"] as? String ?? ""
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let classId = data["classId"] as? String
                let className = classId != nil ? classIdToName[classId!] : nil
                
                let memo = CoachVoiceMemo(
                    id: document.documentID,
                    url: url,
                    timestamp: timestamp,
                    classId: classId,
                    className: className
                )
                
                loadedMemos.append(memo)
            }
            
            // Update UI
            await MainActor.run {
                bookedClasses = loadedClasses.sorted(by: { $0.date > $1.date })
                comments = loadedComments.sorted(by: { $0.timestamp > $1.timestamp })
                voiceMemos = loadedMemos.sorted(by: { $0.timestamp > $1.timestamp })
                isLoading = false
            }
        } catch {
            print("Error loading coach data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ClassCard: View {
    let classItem: CoachDetailView2.CoachClass
    @State private var showingQRCode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classItem.classTime)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(classItem.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(classItem.isFinished ? "Completed" : "Upcoming")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(classItem.isFinished ? TailwindColors.green100 : TailwindColors.violet100)
                    .foregroundColor(classItem.isFinished ? TailwindColors.green700 : TailwindColors.violet700)
                    .cornerRadius(8)
            }
            
            Button(action: {
                showingQRCode = true
            }) {
                HStack {
                    Image(systemName: "qrcode")
                        .foregroundColor(TailwindColors.violet600)
                    Text("View QR Code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TailwindColors.violet600)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(TailwindColors.violet50)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(classId: classItem.id, classTime: classItem.classTime, date: classItem.date)
        }
    }
}

struct QRCodeView: View {
    let classId: String
    let classTime: String
    let date: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Class QR Code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 8) {
                    Text(classTime)
                        .font(.headline)
                    
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.gray)
                }
                
                // QR Code Image
                Image(uiImage: generateQRCode(from: classId))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .background(Color.white)
                    .padding()
                
                Text("Show this QR code to your coach for verification")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

struct CoachCommentCard: View {
    let comment: CoachDetailView2.CoachComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(comment.text)
                .font(.body)
            
            HStack {
                if let className = comment.className {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Class: \(className)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text(comment.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct CoachVoiceMemoCard: View {
    let memo: CoachDetailView2.CoachVoiceMemo
    @State private var isPlaying = false
    private let audioPlayer = AudioPlayer2()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Play button and title
            HStack {
                Button(action: {
                    if isPlaying {
                        audioPlayer.stop()
                    } else {
                        audioPlayer.play(url: URL(string: memo.url)!)
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(TailwindColors.violet400)
                }
                
                Text("Voice Memo")
                    .font(.subheadline)
                    .foregroundColor(isPlaying ? TailwindColors.violet600 : .primary)
                
                Spacer()
                
                Text(memo.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Optional class reference
            if let className = memo.className {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Class: \(className)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

// AudioPlayer class
class AudioPlayer2: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    
    func play(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Handle audio playback completion if needed
    }
} 
