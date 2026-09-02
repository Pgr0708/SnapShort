//
//  ContentSearchService.swift
//  SnapShort
//

import Foundation
import Photos
import UIKit
import Vision
import os.log

// MARK: - Types

struct ContentSearchResult: Identifiable {
    let id = UUID()
    let assetLocalIdentifier: String
    let matchedTag: String
    let confidence: Float
}

protocol ContentSearchServicing {
    func indexLibrary(progress: ScanProgress) async
    func search(query: String) async -> [ContentSearchResult]
    func cancelIndexing() async
}

// MARK: - Service

actor ContentSearchService: ContentSearchServicing {
    private let visionStore: VisionCacheStore
    private let batchProcessor: BatchVisionProcessor
    private var currentTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.snapsort.vision", category: "content")
    
    /// Synonym map for common Vision label aliases
    private static let synonyms: [String: [String]] = [
        "puppy": ["dog"], "kitten": ["cat"], "auto": ["car", "vehicle"],
        "automobile": ["car", "vehicle"], "food": ["meal", "dish", "cuisine"],
        "selfie": ["person", "face"], "baby": ["infant", "child"],
        "holiday": ["vacation", "travel"], "sea": ["ocean", "water", "beach"],
        "mountain": ["hill", "nature", "landscape"], "building": ["architecture", "structure"]
    ]
    
    init(visionStore: VisionCacheStore, batchProcessor: BatchVisionProcessor) {
        self.visionStore = visionStore
        self.batchProcessor = batchProcessor
    }
    
    func indexLibrary(progress: ScanProgress) async {
        let task = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { progress.reset(service: "Content Tagging", total: 0) }
            
            do {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                let assetArray = (0..<allAssets.count).map { allAssets.object(at: $0) }
                
                guard !assetArray.isEmpty else {
                    await MainActor.run { progress.finish() }
                    return
                }
                
                var batch: [ContentTagData] = []
                
                try await batchProcessor.process(
                    assets: assetArray,
                    recordType: .contentTag,
                    chunkSize: 50,
                    targetSize: CGSize(width: 384, height: 384),
                    contentMode: .aspectFit,
                    deliveryMode: .opportunistic,
                    progress: progress,
                    serviceName: "ContentSearch"
                ) { asset, image in
                    guard let result = try? await self.classify(image: image) else { return }
                    batch.append(ContentTagData(
                        assetLocalIdentifier: asset.localIdentifier,
                        tags: result.tags.joined(separator: ","),
                        tagConfidences: result.confidencesData
                    ))
                    
                    // Flush every 50 records
                    if batch.count >= 50 {
                        let toFlush = batch
                        batch.removeAll()
                        try await self.visionStore.upsertContentTags(toFlush)
                    }
                }
                
                if !batch.isEmpty {
                    try await visionStore.upsertContentTags(batch)
                }
                
                await MainActor.run { progress.finish() }
                
            } catch {
                logger.error("Content indexing failed: \(error.localizedDescription)")
                await MainActor.run { progress.finish() }
            }
        }
        self.currentTask = task
        _ = await task.value
        self.currentTask = nil
    }
    
    func search(query: String) async -> [ContentSearchResult] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        
        // Expand with synonyms
        var searchTerms = [normalized]
        if let synonymList = Self.synonyms[normalized] {
            searchTerms.append(contentsOf: synonymList)
        }
        
        var seen = Set<String>()
        var allResults: [ContentSearchResult] = []
        for term in searchTerms {
            let results = await visionStore.searchContentTags(query: term)
            for r in results where !seen.contains(r.identifier) {
                seen.insert(r.identifier)
                // Find which tag actually matched
                let matchedTag = r.tags.components(separatedBy: ",")
                    .first { $0.lowercased().contains(term) } ?? term
                allResults.append(ContentSearchResult(
                    assetLocalIdentifier: r.identifier,
                    matchedTag: matchedTag,
                    confidence: r.confidence
                ))
            }
        }
        
        return allResults.sorted { $0.confidence > $1.confidence }
    }
    
    func cancelIndexing() async {
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - Private
    
    private func classify(image: UIImage) async throws -> (tags: [String], confidencesData: Data) {
        guard let cgImage = image.cgImage else { return ([], Data()) }
        
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else { return ([], Data()) }
        
        // Keep top 5 with confidence > 0.3
        let filtered = observations
            .filter { $0.confidence > 0.3 }
            .prefix(5)
        
        let tags = filtered.map { $0.identifier }
        var confidences = filtered.map { $0.confidence }
        let data = Data(bytes: &confidences, count: confidences.count * MemoryLayout<Float>.size)
        
        return (tags, data)
    }
}
