//
//  SettingsManager.swift
//  GoViral
//
//  Created by Minaxi on 16/08/26.
//

import SwiftUI
internal import Combine
import Photos

@MainActor
final class SettingsManager: ObservableObject {

    // MARK: - App Settings

    @AppStorage(AppStorageKeys.languageCode)
    var languageCode = Languages.english.shortCode.lowercased() {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.isDarkMode)
    var isDarkMode = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.hasSeenLanguage)
    var hasSeenLanguage = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.hasSeenPaywall)
    var hasSeenPaywall = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.hasSeenOnboarding)
    var hasSeenOnboarding = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.hasSeenNotificationPrompt)
    var hasSeenNotificationPrompt = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.notificationsEnabled)
    var notificationsEnabled = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.hasSeenCustomization)
    var hasSeenCustomization = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.selectedAccentColor)
    var selectedAccentColor = AppAccentColor.teal.rawValue {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.isPremium)
    var isPremium = true {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppStorageKeys.selectedTheme)
    var selectedTheme = AppTheme.system.rawValue {
        didSet {
            objectWillChange.send()
        }
    }


    // MARK: - Photo Permission

    @Published
    private(set) var photoAuthorizationStatus: PHAuthorizationStatus =
        PHPhotoLibrary.authorizationStatus(for: .readWrite)

    @AppStorage(AppStorageKeys.hasPhotosAccess)
    var hasPhotosAccess = false {
        didSet {
            objectWillChange.send()
        }
    }


    // MARK: - Computed Properties

    var selectedAppAccentColor: Color {
        AppAccentColor(rawValue: selectedAccentColor)?.color ?? .teal
    }

    var preferredColorScheme: ColorScheme? {
        switch AppTheme(rawValue: selectedTheme) {

        case .light:
            return .light

        case .dark:
            return .dark

        case .system, .none:
            return nil
        }
    }

    // MARK: - Initialization

    init() {
        refreshPhotoAuthorizationStatus()
    }


    // MARK: - Photo Permission

    func requestPhotosPermission() {

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in

            Task { @MainActor in

                guard let self else { return }

                self.photoAuthorizationStatus = status

                self.hasPhotosAccess =
                    status == .authorized ||
                    status == .limited
            }
        }
    }


    func refreshPhotoAuthorizationStatus() {

        let status =
            PHPhotoLibrary.authorizationStatus(for: .readWrite)

        photoAuthorizationStatus = status

        hasPhotosAccess =
            status == .authorized ||
            status == .limited
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { self.rawValue }
}

enum AppAccentColor: String, CaseIterable, Identifiable {
    case teal = "Teal"
    case ocean = "Ocean"
    case purple = "Purple"
    case amber = "Amber"
    case emerald = "Emerald"
    
    var id: String { self.rawValue }
    var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    
    var color: Color {
        switch self {
        case .teal: return Color(hex: "#0A9396")
        case .ocean: return Color(hex: "#0066FF")
        case .purple: return Color(hex: "#8A2BE2")
        case .amber: return Color(hex: "#FFBF00")
        case .emerald: return Color(hex: "#00A86B")
        }
    }
}
