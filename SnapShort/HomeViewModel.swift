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
    
    var hint: String {
        switch self {
        case .textInImage: return "Tip: Run \"Index Text\" first to enable OCR search."
        case .findObject:  return "Tip: Run \"Tag Photos\" first to enable object search."
        }
    }
}

// MARK: - ViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let duplicateService: DuplicateDetectionServicing
    private let textRecognitionService: TextRecognitionServicing
    private let contentSearchService: ContentSearchServicing
    private let unifiedSearchService: UnifiedSearchServicing
    
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
    
    // MARK: - Init
    
    init(
        duplicateService: DuplicateDetectionServicing,
        textRecognitionService: TextRecognitionServicing,
        contentSearchService: ContentSearchServicing,
        unifiedSearchService: UnifiedSearchServicing
    ) {
        self.duplicateService = duplicateService
        self.textRecognitionService = textRecognitionService
        self.contentSearchService = contentSearchService
        self.unifiedSearchService = unifiedSearchService
    }
    
    // MARK: - Duplicate Detection
    
    func promptDuplicateScan() {
        showSensitivityPicker = true
    }
    
    func startDuplicateScan(sensitivity: DuplicateSensitivity? = nil) {
        guard !isScanning else { return }
        if let sensitivity { selectedSensitivity = sensitivity }
        isScanning = true
        scanError = nil
        showSensitivityPicker = false
        
        let progress = ScanProgress()
        self.scanProgress = progress
        self.scanServiceName = "Finding Duplicates"
        
        Task {
            await duplicateService.scanLibrary(sensitivityLevel: selectedSensitivity, progress: progress)
            let clusters = await duplicateService.getDuplicateClusters(sensitivityLevel: selectedSensitivity)
            self.duplicateClusters = clusters
            self.isScanning = false
            self.scanProgress = nil
            
            if clusters.isEmpty {
                self.scanError = "No duplicates found in your library."
            } else {
                self.showDuplicateResults = true
            }
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
                    if self?.duplicateClusters.isEmpty == true {
                        self?.showDuplicateResults = false
                        self?.scanError = "All duplicates deleted!"
                    }
                } else {
                    self?.scanError = "Delete failed: \(error?.localizedDescription ?? "unknown error")"
                }
            }
        }
    }
    
    func cancelScan() {
        Task {
            await duplicateService.cancelScan()
            await textRecognitionService.cancelIndexing()
            await contentSearchService.cancelIndexing()
            isScanning = false
            scanProgress = nil
        }
    }
    
    // MARK: - OCR Indexing
    
    func startOCRIndexing() {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        let progress = ScanProgress()
        self.scanProgress = progress
        self.scanServiceName = "Indexing Text (OCR)"
        Task {
            await textRecognitionService.indexScreenshots(progress: progress)
            self.isScanning = false
            self.scanProgress = nil
            self.scanError = "Text indexing complete! You can now search text inside screenshots."
        }
    }
    
    // MARK: - Content Tag Indexing
    
    func startContentTagIndexing() {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        let progress = ScanProgress()
        self.scanProgress = progress
        self.scanServiceName = "Tagging Photos"
        Task {
            await contentSearchService.indexLibrary(progress: progress)
            self.isScanning = false
            self.scanProgress = nil
            self.scanError = "Photo tagging complete! You can now search by objects and scenes."
        }
    }
    
    // MARK: - Search
    
    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            activeSearch = false
            searchResults = []
            return
        }
        
        activeSearch = true
        isSearching = true
        
        Task {
            switch searchMode {
            case .textInImage:
                // OCR text search
                let results = await unifiedSearchService.search(query: query)
                self.searchResults = results.combinedAndDeduplicated
                
            case .findObject:
                // Content tag / object search
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
        searchQuery = ""
        activeSearch = false
        searchResults = []
    }
}
