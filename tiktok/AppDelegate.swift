//
//  AppDelegate.swift
//  tiktok
//
//  Created by Rostam on 2/3/25.
//
import Swift
import SwiftUI
import VideoEditorSDK

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize img.ly Video Editor SDK with license file
        if let licenseURL = Bundle.main.url(forResource: "license", withExtension: "") {
            VESDK.unlockWithLicense(at: licenseURL)
        } else {
            print("License file not found. The editor will work with a watermark.")
        }
        
        // Perform any custom setup if needed.
        return true
    }
}
