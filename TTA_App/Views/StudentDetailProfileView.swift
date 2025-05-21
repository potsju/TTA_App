import SwiftUI
import FirebaseFirestore

// This file was renamed from StudentProfileView.swift to StudentDetailProfileView.swift to avoid conflicts
struct StudentDetailView: View {
    let studentId: String
    @Environment(\.dismiss) var dismiss
    @State private var student: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Profile")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                    }
                } else if let profile = student {
                    ScrollView {
                        VStack(alignment: .center, spacing: 24) {
                            // Profile Image
                            ZStack {
                                Circle()
                                    .fill(Color(red: 167/255, green: 139/255, blue: 250/255)) // TailwindColors.violet400
                                    .frame(width: 120, height: 120)
                                
                                if !profile.profileImageURL.isEmpty {
                                    // Use AsyncImage if you have a real image URL
                                    AsyncImage(url: URL(string: profile.profileImageURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Text(profile.firstName.prefix(1) + profile.lastName.prefix(1))
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                } else {
                                    Text(profile.firstName.prefix(1) + profile.lastName.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.top, 24)
                            
                            // Name
                            Text(profile.fullName)
                                .font(.system(size: 24, weight: .bold))
                            
                            // Role Badge
                            Text(profile.role)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 237/255, green: 233/255, blue: 254/255)) // TailwindColors.violet100
                                .foregroundColor(Color(red: 91/255, green: 33/255, blue: 182/255)) // TailwindColors.violet800
                                .cornerRadius(20)
                            
                            // Details
                            VStack(spacing: 16) {
                                // Email
                                StudentProfileInfoRow(icon: "envelope.fill", title: "Email", value: profile.email)
                                
                                // Phone
                                StudentProfileInfoRow(icon: "phone.fill", title: "Phone", value: profile.phoneNumber.isEmpty ? "Not provided" : profile.phoneNumber)
                                
                                // Date of Birth
                                StudentProfileInfoRow(icon: "calendar", title: "Date of Birth", value: formatDate(profile.dateOfBirth))
                                
                                // Gender
                                StudentProfileInfoRow(icon: "person.fill", title: "Gender", value: profile.gender.isEmpty ? "Not specified" : profile.gender)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 24)
                    }
                } else {
                    Text("Student not found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Student Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            })
            .task {
                await loadStudentProfile()
            }
        }
    }
    
    private func loadStudentProfile() async {
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(studentId).getDocument()
            
            if document.exists, let data = document.data() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                // Extract date of birth
                var dob = Date()
                if let dobTimestamp = data["dateOfBirth"] as? Timestamp {
                    dob = dobTimestamp.dateValue()
                } else if let dobString = data["dateOfBirth"] as? String {
                    dob = dateFormatter.date(from: dobString) ?? Date()
                }
                
                // Create the user profile
                let profile = UserProfile(
                    id: document.documentID,
                    firstName: data["firstName"] as? String ?? "",
                    lastName: data["lastName"] as? String ?? "",
                    dateOfBirth: dob,
                    phoneNumber: data["phoneNumber"] as? String ?? "",
                    gender: data["gender"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    profileImageURL: data["profileImageURL"] as? String ?? "",
                    role: data["role"] as? String ?? "Student"
                )
                
                DispatchQueue.main.async {
                    self.student = profile
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Student profile not found"
                    self.isLoading = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error loading profile: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct StudentProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: 124/255, green: 58/255, blue: 237/255)) // TailwindColors.violet600
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// Fixed unique name for the preview provider
struct StudentDetail_View_Previews: PreviewProvider {
    static var previews: some View {
        StudentDetailView(studentId: "sample-id")
    }
} 