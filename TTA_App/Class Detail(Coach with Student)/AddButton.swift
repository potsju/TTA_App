//
//  AddButton.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct AddButton: View {
    var body: some View {
        Button(action: {
            // Add button action
        }) {
            ZStack {
                Circle()
                    .strokeBorder(Color.black, lineWidth: 4)
                    .frame(width: 30, height: 30)

                // Horizontal line
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 15.6, height: 2.4)
                    .cornerRadius(1)

                // Vertical line
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2.4, height: 15.6)
                    .cornerRadius(1)
            }
            .frame(width: 30, height: 30)
        }
    }
}

struct AddButton_Previews: PreviewProvider {
    static var previews: some View {
        AddButton()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.white)
    }
}
