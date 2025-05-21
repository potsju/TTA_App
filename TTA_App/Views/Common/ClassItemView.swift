//
//  ClassItemView.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct ClassItemView: View {
    let instructorName: String
    let classTime: String
    let creditCost: Int
    let startTime: Date
    let endTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(classTime)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("\(creditCost) credits")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("Booked")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(TailwindColors.violet200)
                    .foregroundColor(TailwindColors.violet800)
                    .cornerRadius(8)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Text("Coach: \(instructorName)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text(startTime.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
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

struct ClassItemView_Previews: PreviewProvider {
    static var previews: some View {
        ClassItemView(
            instructorName: "Hailong Shen",
            classTime: "4:00-5:30 pm",
            creditCost: 50,
            startTime: Date(),
            endTime: Date().addingTimeInterval(5400) // 90 minutes
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.white)
    }
}
