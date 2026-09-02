//
//  DuplicateDetectionService.swift
//  SnapShort
//

import Foundation
import Photos
import UIKit
import CocoaImageHashing
import os.log

// MARK: - Types

enum DuplicateSensitivity: CaseIterable {
    case strict
    case balanced
    case aggressive
    
    var threshold: Int {
        switch self {
        case .strict: return 3
        case .balanced: return 5
        case .aggressive: return 10
        }
    }
    
    var displayName: String {
        switch self {
        case .strict: return "Strict"
        case .balanced: return "Balanced"
        case .aggressive: return "Aggressive"
        }
    }
}

struct DuplicateCluster: Identifiable {
    let id = UUID()
    let assetIdentifiers: [String]
    let recommendedKeepIdentifier: String
}

protocol DuplicateDetectionServicing {
    func scanLibrary(sensitivityLevel: DuplicateSensitivity, progress: ScanProgress) async
    func getDuplicateClusters(sensitivityLevel: DuplicateSensitivity) async -> [DuplicateCluster]
    func cancelScan() async
}

// MARK: - Helpers

private actor HashBatchCollector {
    private var batch: [ImageHashData] = []
    private let visionStore: VisionCacheStore
    private let threshold: Int
    
    init(visionStore: VisionCacheStore, threshold: Int = 50) {
        self.visionStore = visionStore
        self.threshold = threshold
    }
    
    func add(_ item: ImageHashData) async throws {
        batch.append(item)
        if batch.count >= threshold {
            let toFlush = batch
            batch.removeAll()
            try await visionStore.upsertImageHashes(toFlush)
        }
    }
    
    func flush() async throws {
        guard !batch.isEmpty else { return }
        let toFlush = batch
        batch.removeAll()
        try await visionStore.upsertImageHashes(toFlush)
    }
}

private class UnionFind {
    private var parent: [String: String] = [:]
    private var rank: [String: Int] = [:]
    
    func add(_ id: String) {
        if parent[id] == nil {
            parent[id] = id
            rank[id] = 0
        }
    }
    
    func find(_ x: String) -> String {
        guard let p = parent[x] else { return x }
        if p != x {
            parent[x] = find(p)
        }
        return parent[x] ?? x
    }
    
    func union(_ x: String, _ y: String) {
        let rootX = find(x)
        let rootY = find(y)
        guard rootX != rootY else { return }
        
        let rankX = rank[rootX] ?? 0
        let rankY = rank[rootY] ?? 0
        
        if rankX > rankY {
            parent[rootY] = rootX
        } else if rankX < rankY {
            parent[rootX] = rootY
        } else {
            parent[rootY] = rootX
            rank[rootX] = rankX + 1
        }
    }
    
    func clusters() -> [[String]] {
        var groups: [String: [String]] = [:]
        for id in parent.keys {
            let root = find(id)
            groups[root, default: []].append(id)
        }
        return groups.values.filter { $0.count > 1 }.sorted { $0.count > $1.count }
    }
}

private func hammingDistance(hash1: String, hash2: String) -> Int? {
    guard hash1.count == hash2.count else { return nil }
    var distance = 0
    for (c1, c2) in zip(hash1, hash2) {
        guard let v1 = c1.hexDigitValue, let v2 = c2.hexDigitValue else { return nil }
        let xor = v1 ^ v2
        distance += (xor >> 3) & 1
        distance += (xor >> 2) & 1
        distance += (xor >> 1) & 1
        distance += xor & 1
    }
    return distance
}

// MARK: - Service

actor DuplicateDetectionService: DuplicateDetectionServicing {
    private let visionStore: VisionCacheStore
    private let batchProcessor: BatchVisionProcessor
    private var currentTask: Task<Void, Error>?
    private let logger = Logger(subsystem: "com.snapsort.vision", category: "duplicate")
    
    init(visionStore: VisionCacheStore, batchProcessor: BatchVisionProcessor) {
        self.visionStore = visionStore
        self.batchProcessor = batchProcessor
    }
    
    func scanLibrary(sensitivityLevel: DuplicateSensitivity, progress: ScanProgress) async {
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run { progress.reset(service: "Duplicate Detection", total: 0) }
            
            do {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                let assetArray = (0..<allAssets.count).map { allAssets.object(at: $0) }
                
                guard !assetArray.isEmpty else {
                    await MainActor.run { progress.finish() }
                    return
                }
                
                let collector = HashBatchCollector(visionStore: visionStore)
                
                try await batchProcessor.process(
                    assets: assetArray,
                    recordType: .imageHash,
                    chunkSize: 50,
                    targetSize: CGSize(width: 64, height: 64),
                    contentMode: .aspectFill,
                    deliveryMode: .fastFormat,
                    progress: progress,
                    serviceName: "DuplicateDetection"
                ) { asset, image in
                    let pHash = OSImageHashing.sharedInstance().hashImage(image, with: .pHash)
                    let dHash = OSImageHashing.sharedInstance().hashImage(image, with: .dHash)
                    
                    let pHashString = String(format: "%016llx", pHash)
                    let dHashString = String(format: "%016llx", dHash)
                    
                    let data = ImageHashData(
                        assetLocalIdentifier: asset.localIdentifier,
                        pHashValue: pHashString,
                        dHashValue: dHashString,
                        imageWidth: Int32(asset.pixelWidth),
                        imageHeight: Int32(asset.pixelHeight),
                        captureDate: asset.creationDate
                    )
                    
                    try await collector.add(data)
                }
                
                try await collector.flush()
                await MainActor.run { progress.finish() }
                
            } catch {
                logger.error("Duplicate scan failed: \(error.localizedDescription)")
                await MainActor.run { progress.finish() }
            }
        }
        
        self.currentTask = task
        _ = await task.result
        self.currentTask = nil
    }
    
    func getDuplicateClusters(sensitivityLevel: DuplicateSensitivity) async -> [DuplicateCluster] {
        let allHashes = await visionStore.fetchAllImageHashes()
        
        guard allHashes.count > 1 else { return [] }
        
        // Bucket by (day, roundedAspectRatio)
        var buckets: [[(identifier: String, pHash: String, dHash: String, width: Int, height: Int, date: Date?)]] = []
        var currentBucket: [(identifier: String, pHash: String, dHash: String, width: Int, height: Int, date: Date?)] = []
        var lastDate: Date?
        var lastAspectRatio: Double?
        
        let calendar = Calendar.current
        let dateThreshold: TimeInterval = 24 * 3600
        let aspectRatioTolerance = 0.2
        
        for record in allHashes.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) {
            let aspectRatio = record.height > 0 ? Double(record.width) / Double(record.height) : 1.0
            let roundedAR = (aspectRatio / aspectRatioTolerance).rounded() * aspectRatioTolerance
            
            let recordDay = record.date.map { calendar.startOfDay(for: $0) }
            let lastDay = lastDate.map { calendar.startOfDay(for: $0) }
            
            let sameDay = recordDay == lastDay
            let sameAspect = lastAspectRatio.map { abs($0 - roundedAR) < aspectRatioTolerance } ?? false
            let withinTime = lastDate.map { record.date.map { $0.timeIntervalSince($1) < dateThreshold } ?? false } ?? true
            
            if sameDay && sameAspect && withinTime {
                currentBucket.append(record)
            } else {
                if currentBucket.count > 1 {
                    buckets.append(currentBucket)
                }
                currentBucket = [record]
            }
            
            lastDate = record.date
            lastAspectRatio = roundedAR
        }
        
        if currentBucket.count > 1 {
            buckets.append(currentBucket)
        }
        
        logger.info("Formed \(buckets.count) buckets from \(allHashes.count) hashes")
        
        // Find duplicates within each bucket
        let uf = UnionFind()
        
        for bucket in buckets {
            let ids = bucket.map(\.identifier)
            for id in ids { uf.add(id) }
            
            for i in 0..<bucket.count {
                for j in (i + 1)..<bucket.count {
                    let a = bucket[i]
                    let b = bucket[j]
                    
                    guard let pDist = hammingDistance(hash1: a.pHash, hash2: b.pHash),
                          let dDist = hammingDistance(hash1: a.dHash, hash2: b.dHash) else {
                        continue
                    }
                    
                    let threshold = sensitivityLevel.threshold
                    if pDist <= threshold && dDist <= threshold {
                        uf.union(a.identifier, b.identifier)
                    }
                }
            }
        }
        
        let clusters = uf.clusters()
        logger.info("Found \(clusters.count) duplicate clusters")
        
        let hashDict = Dictionary(uniqueKeysWithValues: allHashes.map { ($0.identifier, $0) })
        
        return clusters.map { ids in
            let recommended = self.recommendedKeep(in: ids, hashDict: hashDict)
            return DuplicateCluster(
                assetIdentifiers: ids,
                recommendedKeepIdentifier: recommended
            )
        }
    }
    
    func cancelScan() async {
        currentTask?.cancel()
        currentTask = nil
        logger.info("Duplicate scan cancelled")
    }
    
    // MARK: - Private
    
    private func recommendedKeep(
        in identifiers: [String],
        hashDict: [String: (identifier: String, pHash: String, dHash: String, width: Int, height: Int, date: Date?)]
    ) -> String {
        let sorted = identifiers.sorted { a, b in
            let recA = hashDict[a]
            let recB = hashDict[b]
            
            let pixelsA = (recA?.width ?? 0) * (recA?.height ?? 0)
            let pixelsB = (recB?.width ?? 0) * (recB?.height ?? 0)
            if pixelsA != pixelsB {
                return pixelsA > pixelsB
            }
            
            let dateA = recA?.date ?? .distantPast
            let dateB = recB?.date ?? .distantPast
            return dateA > dateB
        }
        
        return sorted.first ?? identifiers.first!
    }
}
