//
//  BatchVisionProcessor.swift
//  SnapShort
//

import Foundation
import Photos
import UIKit
import os.log

enum BatchVisionError: Error, LocalizedError {
    case imageFetchFailed
    case thermalThrottling
    
    var errorDescription: String? {
        switch self {
        case .imageFetchFailed:
            return "Failed to fetch image for processing."
        case .thermalThrottling:
            return "Processing paused due to device thermal state."
        }
    }
}

actor BatchVisionProcessor {
    private let cacheManager = PHCachingImageManager()
    private let visionStore: VisionCacheStore
    private let logger = Logger(subsystem: "com.snapsort.vision", category: "batch")
    
    init(visionStore: VisionCacheStore) {
        self.visionStore = visionStore
    }
    
    /// Processes a list of assets in chunks with delta filtering, prefetching,
    /// thermal throttling, and progress reporting.
    func process(
        assets: [PHAsset],
        recordType: RecordType,
        chunkSize: Int = 50,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat,
        progress: ScanProgress,
        serviceName: String,
        using processor: @escaping (PHAsset, UIImage) async throws -> Void
    ) async throws {
        
        // MARK: Delta Processing
        let processedIds = await visionStore.processedIdentifiers(for: recordType)
        let unprocessedAssets = assets.filter { !processedIds.contains($0.localIdentifier) }
        
        guard !unprocessedAssets.isEmpty else {
            logger.info("\(serviceName): all \(assets.count) assets already processed")
            await MainActor.run { progress.finish() }
            return
        }
        
        await MainActor.run {
            progress.reset(service: serviceName, total: unprocessedAssets.count)
        }
        
        let concurrencyLimit = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 4))
        let total = unprocessedAssets.count
        var processedCount = 0
        let chunks = unprocessedAssets.chunked(into: chunkSize)
        
        logger.info("\(serviceName): starting batch of \(total) assets in \(chunks.count) chunks (concurrency: \(concurrencyLimit))")
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            
            // MARK: Thermal / Power Guard
            await waitIfNeededForThermalState()
            
            // MARK: Prefetch next chunk
            if chunkIndex + 1 < chunks.count {
                let nextChunk = chunks[chunkIndex + 1]
                cacheManager.startCachingImages(
                    for: nextChunk,
                    targetSize: targetSize,
                    contentMode: contentMode,
                    options: nil
                )
            }
            
            // Stop caching previous chunk to bound memory
            if chunkIndex > 0 {
                let prevChunk = chunks[chunkIndex - 1]
                cacheManager.stopCachingImages(
                    for: prevChunk,
                    targetSize: targetSize,
                    contentMode: contentMode,
                    options: nil
                )
            }
            
            let chunkStart = Date()
            
            // MARK: Process chunk with limited concurrency
            try await withThrowingTaskGroup(of: Void.self) { group in
                var activeTasks = 0
                
                for asset in chunk {
                    if Task.isCancelled { break }
                    
                    if activeTasks >= concurrencyLimit {
                        try await group.next()
                        activeTasks -= 1
                    }
                    
                    group.addTask {
                        let image = try await self.fetchImage(
                            for: asset,
                            targetSize: targetSize,
                            contentMode: contentMode,
                            deliveryMode: deliveryMode
                        )
                        try await processor(asset, image)
                    }
                    activeTasks += 1
                }
                
                while activeTasks > 0 {
                    try await group.next()
                    activeTasks -= 1
                }
            }
            
            processedCount += chunk.count
            let chunkDuration = Date().timeIntervalSince(chunkStart)
            let remainingChunks = chunks.count - chunkIndex - 1
            let estimatedRemaining = TimeInterval(remainingChunks) * chunkDuration
            
            await MainActor.run {
                progress.update(processed: processedCount, estimatedSecondsRemaining: estimatedRemaining)
            }
            
            logger.info("\(serviceName): chunk \(chunkIndex + 1)/\(chunks.count) complete (\(processedCount)/\(total))")
        }
        
        // Clear any remaining cached images
        if let lastChunk = chunks.last {
            cacheManager.stopCachingImages(
                for: lastChunk,
                targetSize: targetSize,
                contentMode: contentMode,
                options: nil
            )
        }
        
        await MainActor.run {
            progress.finish()
        }
        
        logger.info("\(serviceName): batch complete — \(total) assets processed")
    }
    
    // MARK: - Private
    
    private func fetchImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        return try await withCheckedThrowingContinuation { continuation in
            cacheManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image = image else {
                    continuation.resume(throwing: BatchVisionError.imageFetchFailed)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
    
    private func waitIfNeededForThermalState() async {
        let thermalState = ProcessInfo.processInfo.thermalState
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        guard isLowPower || thermalState == .serious || thermalState == .critical else {
            return
        }
        
        var backoffSeconds: UInt64 = 1
        
        while ProcessInfo.processInfo.thermalState == .serious ||
              ProcessInfo.processInfo.thermalState == .critical ||
              ProcessInfo.processInfo.isLowPowerModeEnabled {
            
            logger.warning(
                "Thermal: \(String(describing: ProcessInfo.processInfo.thermalState)), " +
                "LowPower: \(ProcessInfo.processInfo.isLowPowerModeEnabled). " +
                "Pausing for \(backoffSeconds)s"
            )
            
            try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
            backoffSeconds = min(backoffSeconds * 2, 30)
        }
    }
}

// MARK: - Array Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
