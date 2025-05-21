//
//  GoogleIconView.swift
//  TTA_App
//
//  Created by Darren Choe on 3/24/25.
//

import SwiftUI

struct GoogleIconSVG: View {
    var body: some View {
        Canvas { context, size in
            // Draw the Google "G" logo
            let width: CGFloat = size.width
            let height: CGFloat = size.height

            // Create a path for the Google "G" icon
            var path = Path()

            // This is a simplified version of the Google "G" icon
            path.move(to: CGPoint(x: 0.87 * width, y: 0.42 * height))
            path.addLine(to: CGPoint(x: 0.87 * width, y: 0.51 * height))
            path.addCurve(
                to: CGPoint(x: 0.51 * width, y: 0.91 * height),
                control1: CGPoint(x: 0.87 * width, y: 0.74 * height),
                control2: CGPoint(x: 0.71 * width, y: 0.91 * height)
            )
            path.addCurve(
                to: CGPoint(x: 0.13 * width, y: 0.5 * height),
                control1: CGPoint(x: 0.3 * width, y: 0.91 * height),
                control2: CGPoint(x: 0.13 * width, y: 0.73 * height)
            )
            path.addCurve(
                to: CGPoint(x: 0.51 * width, y: 0.09 * height),
                control1: CGPoint(x: 0.13 * width, y: 0.27 * height),
                control2: CGPoint(x: 0.3 * width, y: 0.09 * height)
            )
            path.addCurve(
                to: CGPoint(x: 0.77 * width, y: 0.2 * height),
                control1: CGPoint(x: 0.61 * width, y: 0.09 * height),
                control2: CGPoint(x: 0.7 * width, y: 0.13 * height)
            )
            path.addLine(to: CGPoint(x: 0.66 * width, y: 0.31 * height))
            path.addCurve(
                to: CGPoint(x: 0.51 * width, y: 0.25 * height),
                control1: CGPoint(x: 0.62 * width, y: 0.27 * height),
                control2: CGPoint(x: 0.57 * width, y: 0.25 * height)
            )
            path.addCurve(
                to: CGPoint(x: 0.28 * width, y: 0.5 * height),
                control1: CGPoint(x: 0.38 * width, y: 0.25 * height),
                control2: CGPoint(x: 0.28 * width, y: 0.36 * height)
            )
            path.addCurve(
                to: CGPoint(x: 0.51 * width, y: 0.75 * height),
                control1: CGPoint(x: 0.28 * width, y: 0.64 * height),
                control2: CGPoint(x: 0.38 * width, y: 0.75 * height)
            )
            path.addCurve(
                to: CGPoint(x: 0.72 * width, y: 0.58 * height),
                control1: CGPoint(x: 0.62 * width, y: 0.75 * height),
                control2: CGPoint(x: 0.7 * width, y: 0.68 * height)
            )
            path.addLine(to: CGPoint(x: 0.51 * width, y: 0.58 * height))
            path.addLine(to: CGPoint(x: 0.51 * width, y: 0.42 * height))
            path.addLine(to: CGPoint(x: 0.87 * width, y: 0.42 * height))
            path.closeSubpath()

            // Draw the path
            context.stroke(path, with: .color(.black), lineWidth: 1.5)
        }
        .frame(width: 16, height: 16)
    }
}

struct GoogleIconView: View {
    var body: some View {
        GoogleIconSVG()
    }
}

struct GoogleIconView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleIconView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
