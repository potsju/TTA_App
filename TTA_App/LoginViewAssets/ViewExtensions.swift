//
//  ViewExtensions.swift
//  TTA_App
//
//  Created by Darren Choe on 3/24/25.
//

import SwiftUI

// MARK: - Padding Extensions
extension View {
    func paddingTailwind(_ edges: Edge.Set = .all, _ size: CGFloat) -> some View {
        self.padding(edges, size)
    }

    func paddingX(_ size: CGFloat) -> some View {
        self.padding(.horizontal, size)
    }

    func paddingY(_ size: CGFloat) -> some View {
        self.padding(.vertical, size)
    }

    func paddingT(_ size: CGFloat) -> some View {
        self.padding(.top, size)
    }

    func paddingB(_ size: CGFloat) -> some View {
        self.padding(.bottom, size)
    }

    func paddingL(_ size: CGFloat) -> some View {
        self.padding(.leading, size)
    }

    func paddingR(_ size: CGFloat) -> some View {
        self.padding(.trailing, size)
    }
}

// MARK: - Margin Extensions (using padding in SwiftUI)
extension View {
    func marginTailwind(_ edges: Edge.Set = .all, _ size: CGFloat) -> some View {
        self.padding(edges, size)
    }

    func marginX(_ size: CGFloat) -> some View {
        self.padding(.horizontal, size)
    }

    func marginY(_ size: CGFloat) -> some View {
        self.padding(.vertical, size)
    }

    func marginT(_ size: CGFloat) -> some View {
        self.padding(.top, size)
    }

    func marginB(_ size: CGFloat) -> some View {
        self.padding(.bottom, size)
    }

    func marginL(_ size: CGFloat) -> some View {
        self.padding(.leading, size)
    }

    func marginR(_ size: CGFloat) -> some View {
        self.padding(.trailing, size)
    }
}

// MARK: - Width and Height Extensions
extension View {
    func widthFull() -> some View {
        self.frame(maxWidth: .infinity)
    }

    func heightFull() -> some View {
        self.frame(maxHeight: .infinity)
    }

    func widthScreen() -> some View {
        self.frame(width: UIScreen.main.bounds.width)
    }

    func heightScreen() -> some View {
        self.frame(height: UIScreen.main.bounds.height)
    }

    func width(_ width: CGFloat) -> some View {
        self.frame(width: width)
    }

    func height(_ height: CGFloat) -> some View {
        self.frame(height: height)
    }

    func size(_ size: CGFloat) -> some View {
        self.frame(width: size, height: size)
    }

    func size(width: CGFloat, height: CGFloat) -> some View {
        self.frame(width: width, height: height)
    }
}

// MARK: - Border Extensions
extension View {
    func borderTailwind(_ color: Color, width: CGFloat = 1, cornerRadius: CGFloat = 0) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
    }

    func roundedCorners(_ radius: CGFloat) -> some View {
        self.cornerRadius(radius)
    }
}

// MARK: - Background Extensions
extension View {
    func bgColor(_ color: Color) -> some View {
        self.background(color)
    }
}

// MARK: - Text Style Extensions
extension Text {
    func textXs() -> Text {
        self.font(.system(size: 12))
    }

    func textSm() -> Text {
        self.font(.system(size: 14))
    }

    func textBase() -> Text {
        self.font(.system(size: 16))
    }

    func textLg() -> Text {
        self.font(.system(size: 18))
    }

    func textXl() -> Text {
        self.font(.system(size: 20))
    }

    func text2xl() -> Text {
        self.font(.system(size: 24))
    }

    func fontLight() -> Text {
        self.fontWeight(.light)
    }

    func fontNormal() -> Text {
        self.fontWeight(.regular)
    }

    func fontMedium() -> Text {
        self.fontWeight(.medium)
    }

    func fontSemibold() -> Text {
        self.fontWeight(.semibold)
    }

    func fontBold() -> Text {
        self.fontWeight(.bold)
    }

    func trackingWide() -> Text {
        self.tracking(0.5)
    }

    func trackingWider() -> Text {
        self.tracking(1.0)
    }

    func trackingWidest() -> Text {
        self.tracking(1.5)
    }
}

// MARK: - Flex Extensions
extension HStack {
    func justifyStart() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
    }

    func justifyCenter() -> some View {
        self.frame(maxWidth: .infinity, alignment: .center)
    }

    func justifyEnd() -> some View {
        self.frame(maxWidth: .infinity, alignment: .trailing)
    }

    func justifyBetween() -> some View {
        self
    }

    func itemsStart() -> some View {
        self.alignmentGuide(.top) { $0[.top] }
    }

    func itemsCenter() -> some View {
        self.alignmentGuide(VerticalAlignment.center) { $0[VerticalAlignment.center] }
    }

    func itemsEnd() -> some View {
        self.alignmentGuide(.bottom) { $0[.bottom] }
    }
}

// MARK: - Shadow Extensions
extension View {
    func shadowSm() -> some View {
        self.shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    func shadowMd() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    func shadowLg() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    func shadowXl() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}
