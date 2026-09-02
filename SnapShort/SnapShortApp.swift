//
//  SnapShortApp.swift
//  SnapShort
//
//  Created by Minaxi on 31/08/26.
//

import SwiftUI
import CoreData

class AppDependencies {
    let visionStore: VisionCacheStore
    let batchProcessor: BatchVisionProcessor
    let duplicateService: DuplicateDetectionService
    let textRecognitionService: TextRecognitionService
    let unifiedSearchService: UnifiedSearchService
    let homeViewModel: HomeViewModel
    
    init() {
        self.visionStore = VisionCacheStore()
        self.batchProcessor = BatchVisionProcessor(visionStore: visionStore)
        self.duplicateService = DuplicateDetectionService(visionStore: visionStore, batchProcessor: batchProcessor)
        self.textRecognitionService = TextRecognitionService(visionStore: visionStore, batchProcessor: batchProcessor)
        self.unifiedSearchService = UnifiedSearchService(textRecognitionService: textRecognitionService)
        self.homeViewModel = HomeViewModel(
            duplicateService: duplicateService,
            textRecognitionService: textRecognitionService,
            unifiedSearchService: unifiedSearchService
        )
    }
}

@main
struct SnapShortApp: App {
    @StateObject private var settings = SettingsManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    private let dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            RootView(homeViewModel: dependencies.homeViewModel)
                .environmentObject(settings)
                .environment(
                    \.locale,
                     Locale(identifier: settings.languageCode)
                     )
                .environment(
                           \.managedObjectContext,
                           CoreDataManager.shared.context
                       )
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
