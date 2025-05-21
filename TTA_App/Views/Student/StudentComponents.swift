import SwiftUI

/// Shared StudentCard component to be used across the app
struct StudentCard: View {
    let student: Student
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let profileImage = student.profileImage {
                    AsyncImage(url: URL(string: profileImage)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(TailwindColors.violet400)
                            .overlay(
                                Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(TailwindColors.violet400)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.fullName)
                        .font(.headline)
                    
                    Text(student.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            // Display booked classes if available
            if let bookedClasses = student.bookedClasses, !bookedClasses.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                Text("Booked Classes:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 2)
                
                ForEach(bookedClasses) { booking in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(booking.date)
                                .font(.footnote)
                                .foregroundColor(.gray)
                            
                            Text(booking.time)
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text(booking.isFinished ? "Completed" : "Upcoming")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(booking.isFinished ? TailwindColors.green100 : TailwindColors.violet100)
                            .foregroundColor(booking.isFinished ? TailwindColors.green700 : TailwindColors.violet700)
                            .cornerRadius(4)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
} 