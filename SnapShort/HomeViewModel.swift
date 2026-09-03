//
//  HomeViewModel.swift
//  SnapShort
//

import SwiftUI
import Photos
internal import Combine

// MARK: - Search Mode

enum SearchMode: String, CaseIterable {
    case textInImage = "Text in Image"
    case findObject  = "Find Object"
    
    var icon: String {
        switch self {
        case .textInImage: return "text.magnifyingglass"
        case .findObject:  return "photo.on.rectangle.angled"
        }
    }
    
    var placeholder: String {
        switch self {
        case .textInImage: return "Search text inside screenshots..."
        case .findObject:  return "Search by object, scene, animal..."
        }
    }
}

// MARK: - ViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Dependencies (exposed for views that need direct access)
    
    let visionStore: VisionCacheStore
    
    private let duplicateService: DuplicateDetectionServicing
    private let textRecognitionService: TextRecognitionServicing
    private let contentSearchService: ContentSearchServicing
    private let unifiedSearchService: UnifiedSearchServicing
    private let categorizationService: SmartCategorizationServicing
    
    // MARK: - Published State
    
    @Published var scanProgress: ScanProgress?
    @Published var duplicateClusters: [DuplicateCluster] = []
    @Published var searchResults: [SearchResultItem] = []
    @Published var searchQuery: String = ""
    @Published var isSearching: Bool = false
    @Published var isScanning: Bool = false
    @Published var showDuplicateResults: Bool = false
    @Published var activeSearch: Bool = false
    @Published var scanServiceName: String = ""
    @Published var scanError: String?
    
    // Search mode toggle
    @Published var searchMode: SearchMode = .textInImage
    
    // Sensitivity picker
    @Published var showSensitivityPicker: Bool = false
    @Published var selectedSensitivity: DuplicateSensitivity = .balanced
    
    // Categories
    @Published var allCategories: [SmartCategory] = []
    @Published var categoryCounts: [String: Int] = [:]
    
    // Clean Up
    @Published var cleanUpAnalysis: CleanUpAnalysis?
    @Published var isAnalyzing: Bool = false
    
    // Background auto-indexing (shown as a non-intrusive banner)
    @Published var isBackgroundIndexing: Bool = false
    @Published var backgroundIndexMessage: String = ""
    @Published var backgroundIndexProgress: Double = 0.0   // 0…1
    
    // OCR readiness state (Text in Image is locked until OCR finishes scanning all photos)
    @Published var isOCRComplete: Bool = true
    @Published var isOCRIndexing: Bool = false
    @Published var ocrIndexProgress: Double = 0.0
    
    // MARK: - Init
    
    private let cleanUpService: CleanUpService
    
    init(
        visionStore: VisionCacheStore,
        duplicateService: DuplicateDetectionServicing,
        textRecognitionService: TextRecognitionServicing,
        contentSearchService: ContentSearchServicing,
        unifiedSearchService: UnifiedSearchServicing,
        categorizationService: SmartCategorizationServicing,
        cleanUpService: CleanUpService = CleanUpService()
    ) {
        self.visionStore = visionStore
        self.duplicateService = duplicateService
        self.textRecognitionService = textRecognitionService
        self.contentSearchService = contentSearchService
        self.unifiedSearchService = unifiedSearchService
        self.categorizationService = categorizationService
        self.cleanUpService = cleanUpService
    }
    
    // MARK: - Duplicate Detection
    
    func promptDuplicateScan() { showSensitivityPicker = true }
    
    func startDuplicateScan(sensitivity: DuplicateSensitivity? = nil) {
        guard !isScanning else { return }
        if let sensitivity { selectedSensitivity = sensitivity }
        isScanning = true; scanError = nil; showSensitivityPicker = false
        let progress = ScanProgress(); self.scanProgress = progress
        self.scanServiceName = "Finding Duplicates"
        Task {
            await duplicateService.scanLibrary(sensitivityLevel: selectedSensitivity, progress: progress)
            let clusters = await duplicateService.getDuplicateClusters(sensitivityLevel: selectedSensitivity)
            self.duplicateClusters = clusters
            self.isScanning = false; self.scanProgress = nil
            if clusters.isEmpty { self.scanError = "No duplicates found." }
            else { self.showDuplicateResults = true }
        }
    }
    
    func deleteDuplicates(in cluster: DuplicateCluster) {
        let toDelete = cluster.assetIdentifiers.filter { $0 != cluster.recommendedKeepIdentifier }
        guard !toDelete.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: toDelete, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        } completionHandler: { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.duplicateClusters.removeAll { $0.id == cluster.id }
                    await self?.purgeDeletedPhotos(identifiers: toDelete)
                    if self?.duplicateClusters.isEmpty == true {
                        self?.showDuplicateResults = false
                        self?.scanError = "All duplicates deleted!"
                    }
                } else { self?.scanError = "Delete failed: \(error?.localizedDescription ?? "unknown")" }
            }
        }
    }
    
    func cancelScan() {
        Task {
            await duplicateService.cancelScan()
            await textRecognitionService.cancelIndexing()
            await contentSearchService.cancelIndexing()
            isScanning = false; scanProgress = nil
        }
    }
    
    // MARK: - OCR Indexing
    
    func startOCRIndexing() {
        guard !isScanning else { return }
        isScanning = true; scanError = nil
        isOCRComplete = false; isOCRIndexing = true
        let progress = ScanProgress(); self.scanProgress = progress
        self.scanServiceName = "Indexing Text (OCR)"
        Task {
            await textRecognitionService.indexScreenshots(progress: progress)
            self.isScanning = false; self.scanProgress = nil
            self.isOCRComplete = true; self.isOCRIndexing = false
            self.ocrIndexProgress = 1.0
            self.scanError = "Text indexing complete! \"Text in Image\" search is now ready."
        }
    }
    
    // MARK: - Content Tag Indexing
    
    func startContentTagIndexing() {
        guard !isScanning else { return }
        isScanning = true; scanError = nil
        let progress = ScanProgress(); self.scanProgress = progress
        self.scanServiceName = "Tagging Photos"
        Task {
            await contentSearchService.indexLibrary(progress: progress)
            self.isScanning = false; self.scanProgress = nil
            self.scanError = "Photo tagging complete! You can now search by objects and scenes."
        }
    }
    
    // MARK: - Background Auto-Indexing (runs on app launch, incremental / delta only)
    
    /// Called once when the app appears. Silently indexes only new/un-cached photos.
    /// If everything is already indexed it finishes in milliseconds with no banner shown.
    func autoIndexInBackground() {
        guard !isBackgroundIndexing else { return }
        
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            
            // ── Pre-check pending items ──────────────────────────────────────
            let processedOCRIds = await self.visionStore.processedIdentifiers(for: .ocrText)
            let processedTagIds = await self.visionStore.processedIdentifiers(for: .contentTag)
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(
                format: "mediaSubtype == %ld",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            let screenshots = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var unindexedOCRCount = 0
            screenshots.enumerateObjects { a, _, _ in
                if !processedOCRIds.contains(a.localIdentifier) {
                    unindexedOCRCount += 1
                }
            }
            
            let allImages = PHAsset.fetchAssets(with: .image, options: nil)
            var unindexedTagCount = 0
            allImages.enumerateObjects { a, _, _ in
                if !processedTagIds.contains(a.localIdentifier) {
                    unindexedTagCount += 1
                }
            }
            
            await MainActor.run {
                self.isOCRComplete = (unindexedOCRCount == 0)
                self.isOCRIndexing = (unindexedOCRCount > 0)
            }
            
            // If everything is already cached, exit immediately without showing any banner!
            guard unindexedOCRCount > 0 || unindexedTagCount > 0 else {
                await MainActor.run {
                    self.isOCRComplete = true
                    self.isOCRIndexing = false
                    self.ocrIndexProgress = 1.0
                    self.isBackgroundIndexing = false
                }
                return
            }
            
            await MainActor.run {
                self.isBackgroundIndexing = true
            }
            
            let hasOCRWork = unindexedOCRCount > 0
            let hasTagWork = unindexedTagCount > 0
            
            // ── Phase 1: OCR (if needed) ────────────────────────────────────
            if hasOCRWork {
                let ocrProgress = ScanProgress()
                let ocrPoller = Task { @MainActor in
                    // Wait for scanning to actually start (reset() sets isScanning=true)
                    while !ocrProgress.isScanning {
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                        if Task.isCancelled { return }
                    }
                    // Now poll until finished
                    while ocrProgress.isScanning {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms poll
                        if Task.isCancelled { return }
                        let frac = ocrProgress.fractionCompleted
                        self.ocrIndexProgress = frac
                        self.backgroundIndexMessage = "Scanning text (\(ocrProgress.processedCount)/\(ocrProgress.totalCount))…"
                        let weight = hasTagWork ? 0.5 : 1.0
                        self.backgroundIndexProgress = frac * weight
                    }
                }
                await self.textRecognitionService.indexScreenshots(progress: ocrProgress)
                ocrPoller.cancel()
                
                await MainActor.run {
                    self.isOCRComplete = true
                    self.isOCRIndexing = false
                    self.ocrIndexProgress = 1.0
                }
            }
            
            // ── Phase 2: Vision Tagging (if needed) ──────────────────────────
            if hasTagWork {
                let tagProgress = ScanProgress()
                let baseProgress = hasOCRWork ? 0.5 : 0.0
                let weight = hasOCRWork ? 0.5 : 1.0
                
                let tagPoller = Task { @MainActor in
                    // Wait for scanning to actually start
                    while !tagProgress.isScanning {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        if Task.isCancelled { return }
                    }
                    // Now poll until finished
                    while tagProgress.isScanning {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        if Task.isCancelled { return }
                        let frac = tagProgress.fractionCompleted
                        self.backgroundIndexMessage = "Tagging objects (\(tagProgress.processedCount)/\(tagProgress.totalCount))…"
                        self.backgroundIndexProgress = baseProgress + frac * weight
                    }
                }
                await self.contentSearchService.indexLibrary(progress: tagProgress)
                tagPoller.cancel()
            }
            
            // ── Completion & Auto-Dismiss ───────────────────────────────────
            await MainActor.run {
                self.backgroundIndexProgress = 1.0
                self.backgroundIndexMessage = "✓ Search is ready!"
            }
            
            // Keep visible for 1.8s so user sees completion
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.isBackgroundIndexing = false
                    self.backgroundIndexProgress = 0.0
                    self.backgroundIndexMessage = ""
                }
            }
        }
    }
    
    // MARK: - Smart Categorization
    
    func loadCategories() async {
        let categories = await categorizationService.getAllCategories()
        self.allCategories = categories
    }
    
    func buildCategoryIndex() async {
        let counts = await categorizationService.categorizeLibrary()
        let _ = counts  // triggers internal cache build
        let categories = await categorizationService.getAllCategories()
        self.allCategories = categories
        self.categoryCounts = categories.reduce(into: [:]) { $0[$1.id] = $1.photoCount }
    }
    
    func fetchAssets(for category: SmartCategory) async -> [String] {
        await categorizationService.fetchAssets(for: category)
    }
    
    func addCustomCategory(name: String, icon: String, colorHex: String, keywords: [String]) async {
        try? await categorizationService.addUserCategory(name: name, icon: icon, colorHex: colorHex, keywords: keywords)
        await loadCategories()
    }
    
    func editCustomCategory(id: String, name: String, icon: String, colorHex: String, keywords: [String]) async {
        let keywordsString = keywords.joined(separator: ",")
        try? await visionStore.saveUserCategory(id: id, name: name, iconName: icon, colorHex: colorHex, keywords: keywordsString)
        // Invalidate category map cache
        await categorizationService.invalidateCache()
        await loadCategories()
    }
    
    func deleteCustomCategory(id: String) async {
        try? await categorizationService.deleteUserCategory(id: id)
        allCategories.removeAll { $0.id == id }
    }
    
    /// Creates a real album in the Photos app containing all assets for this category.
    func saveAsAlbum(category: SmartCategory) async {
        let assetIds = await fetchAssets(for: category)
        guard !assetIds.isEmpty else {
            scanError = "No photos in \"\(category.name)\" to save as album."
            return
        }
        
        let albumTitle = "\(category.emoji) \(category.name)"
        
        // Check if album already exists
        var existingCollection: PHAssetCollection?
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", albumTitle)
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        existingCollection = existing.firstObject
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if let collection = existingCollection {
                    // Add to existing album
                    guard let req = PHAssetCollectionChangeRequest(for: collection) else { return }
                    req.addAssets(fetchResult)
                } else {
                    // Create new album
                    let createReq = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                    let placeholder = createReq.placeholderForCreatedAssetCollection
                    let albumFetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                    guard let newAlbum = albumFetch.firstObject,
                          let req = PHAssetCollectionChangeRequest(for: newAlbum) else { return }
                    req.addAssets(fetchResult)
                }
            }
            await MainActor.run {
                self.scanError = "✅ Album \"\(albumTitle)\" saved to Photos!"
            }
        } catch {
            await MainActor.run {
                self.scanError = "Failed to save album: \(error.localizedDescription)"
            }
        }
    }
    
    /// Deletes a photo from the Photos library (Apple shows native confirmation popup) and purges from Core Data.
    func deletePhoto(identifier: String) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard fetchResult.count > 0 else { return }
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        } completionHandler: { [weak self] success, error in
            Task { @MainActor in
                if success {
                    await self?.purgeDeletedPhotos(identifiers: [identifier])
                } else if let error {
                    self?.scanError = "Delete failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Cleans Core Data cache and invalidates categories whenever photos are deleted from any tab.
    func purgeDeletedPhotos(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        await visionStore.purgeDeletedAssets(identifiers: identifiers)
        await categorizationService.invalidateCache()
        await loadCategories()
        let idSet = Set(identifiers)
        searchResults.removeAll { idSet.contains($0.assetLocalIdentifier) }
    }
    
    // MARK: - Photo Notes
    
    func savePhotoNote(assetId: String, note: String) async {
        try? await visionStore.savePhotoNote(assetId: assetId, userNote: note)
    }
    
    func fetchPhotoNote(for assetId: String) async -> String {
        let result = await visionStore.fetchPhotoNote(for: assetId)
        return result.userNote
    }
    
    // MARK: - Search
    
    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { activeSearch = false; searchResults = []; return }
        
        if searchMode == .textInImage && !isOCRComplete {
            scanError = "Text in photos is still being scanned. \"Text in Image\" search will unlock automatically once complete."
            return
        }
        
        activeSearch = true; isSearching = true
        Task {
            switch searchMode {
            case .textInImage:
                let results = await unifiedSearchService.search(query: query)
                self.searchResults = results.combinedAndDeduplicated
            case .findObject:
                let results = await contentSearchService.search(query: query)
                self.searchResults = results.map { r in
                    SearchResultItem(
                        assetLocalIdentifier: r.assetLocalIdentifier,
                        title: r.matchedTag.capitalized,
                        subtitle: "Object match · \(Int(r.confidence * 100))% confidence",
                        relevanceScore: Double(r.confidence),
                        source: .contentTag
                    )
                }
            }
            self.isSearching = false
        }
    }
    
    func clearSearch() {
        searchQuery = ""; activeSearch = false; searchResults = []
    }
    
    // MARK: - Clean Up
    
    func analyzeForCleanUp() async {
        isAnalyzing = true
        
        // Reuse existing duplicate scan (balanced sensitivity)
        let progress = ScanProgress()
        await duplicateService.scanLibrary(sensitivityLevel: .balanced, progress: progress)
        let clusters = await duplicateService.getDuplicateClusters(sensitivityLevel: .balanced)
        
        // Collect duplicate ids (all except recommended keep)
        var dupeIds: [String] = []
        for cluster in clusters {
            let others = cluster.assetIdentifiers.filter { $0 != cluster.recommendedKeepIdentifier }
            dupeIds.append(contentsOf: others)
        }
        
        // Run CleanUpService analyses in parallel
        let analysis = await cleanUpService.analyze(existingDuplicateIds: dupeIds)
        self.cleanUpAnalysis = analysis
        self.isAnalyzing = false
    }
    
    func identifiers(for type: CleanUpCategoryType) -> [String] {
        guard let analysis = cleanUpAnalysis else { return [] }
        return type.identifiers(from: analysis)
    }
}
