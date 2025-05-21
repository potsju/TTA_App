//
//  RootViewControllerExtension.swift
//  TTA_App
//
//  Created by Darren Choe on 3/26/25.
//

import SwiftUI

extension UIApplication {
    static var rootViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.rootViewController
    }
}
