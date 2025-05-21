//
//  BackButton.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct BackButton: View {
    var body: some View {
        Button(action: {
            // Back button action
        }) {
            BackArrowShape()
                .fill(Color(red: 0.64, green: 0.64, blue: 0.71))
                .frame(width: 24, height: 24)
        }
    }
}

struct BackArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Drawing the back arrow shape based on the SVG path
        path.move(to: CGPoint(x: 0.174 * width, y: 0))
        path.addCurve(
            to: CGPoint(x: 0.46 * width, y: 0.29 * height),
            control1: CGPoint(x: 0.3 * width, y: 0),
            control2: CGPoint(x: 0.4 * width, y: 0.1 * height)
        )
        path.addLine(to: CGPoint(x: 0.71 * width, y: 0.54 * height))
        path.addCurve(
            to: CGPoint(x: 0.71 * width, y: 0.46 * height),
            control1: CGPoint(x: 0.76 * width, y: 0.5 * height),
            control2: CGPoint(x: 0.76 * width, y: 0.5 * height))
        path.addLine(to: CGPoint(x: 0.46 * width, y: 0.71 * height))
        path.addCurve(
            to: CGPoint(x: 0.174 * width, y: height),
            control1: CGPoint(x: 0.4 * width, y: 0.9 * height),
            control2: CGPoint(x: 0.3 * width, y: height))
        path.addCurve(
            to: CGPoint(x: 0.12 * width, y: 0.71 * height),
            control1: CGPoint(x: 0.12 * width, y: 0.9 * height),
            control2: CGPoint(x: 0.1 * width, y: 0.8 * height))
        path.addLine(to: CGPoint(x: 0.29 * width, y: 0.54 * height))
        path.addCurve(
            to: CGPoint(x: 0.29 * width, y: 0.46 * height),
            control1: CGPoint(x: 0.24 * width, y: 0.5 * height),
            control2: CGPoint(x: 0.24 * width, y: 0.5 * height))
        path.addLine(to: CGPoint(x: 0.12 * width, y: 0.29 * height))
        path.addCurve(
            to: CGPoint(x: 0.174 * width, y: 0),
            control1: CGPoint(x: 0.1 * width, y: 0.2 * height),
            control2: CGPoint(x: 0.12 * width, y: 0.1 * height))
        path.closeSubpath()

        return path
    }
}

struct BackButton_Previews: PreviewProvider {
    static var previews: some View {
        BackButton()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.white)
    }
}
