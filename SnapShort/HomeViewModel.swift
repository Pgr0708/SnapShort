//
//  HomeViewModel.swift
//  SnapShort
//

import SwiftUI
import Photos
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let duplicateService: DuplicateDetectionServicing
    private let textRecognitionService: TextRecognitionServicing
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
    
    // MARK: - Init
    
    init(
        duplicateService: DuplicateDetectionServicing,
        textRecognitionService: TextRecognitionServicing,
        unifiedSearchService: UnifiedSearchServicing
    ) {
        self.duplicateService = duplicateService
        self.textRecognitionService = textRecognitionService
        self.unifiedSearchService = unifiedSearchService
    }
    
    // MARK: - Duplicate Detection
    
    func startDuplicateScan(sensitivity: DuplicateSensitivity = .balanced) {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        
        let progress = ScanProgress()
        self.scanProgress = progress
        self.scanServiceName = "Finding Duplicates"
        
        Task {
            await duplicateService.scanLibrary(sensitivityLevel: sensitivity, progress: progress)
            
            let clusters = await duplicateService.getDuplicateClusters(sensitivityLevel: sensitivity)
            self.duplicateClusters = clusters
            self.isScanning = false
            self.scanProgress = nil
            
            if clusters.isEmpty {
                self.scanError = "No duplicates found."
            } else {
                self.showDuplicateResults = true
            }
        }
    }
    
    func cancelScan() {
        Task {
            await duplicateService.cancelScan()
            await textRecognitionService.cancelIndexing()
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
        self.scanServiceName = "Indexing Text"
        
        Task {
            await textRecognitionService.indexScreenshots(progress: progress)
            self.isScanning = false
            self.scanProgress = nil
            self.scanError = "Text indexing complete."
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
            let results = await unifiedSearchService.search(query: query)
            self.searchResults = results.combinedAndDeduplicated
            self.isSearching = false
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        activeSearch = false
        searchResults = []
    }
}
