//
//  TextRecognitionService.swift
//  SnapShort
//

import Foundation
import Photos
import UIKit
import Vision
import os.log

// MARK: - Types

struct OCRSearchResult: Identifiable {
    let id = UUID()
    let assetLocalIdentifier: String
    let extractedText: String
    let snippet: String
    let confidence: Float
}

enum TextRecognitionError: Error, LocalizedError {
    case cgImageConversionFailed
    case visionRequestFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .cgImageConversionFailed:
            return "Unable to convert image for text recognition."
        case .visionRequestFailed(let error):
            return "Vision request failed: \(error.localizedDescription)"
        }
    }
}

protocol TextRecognitionServicing {
    func indexScreenshots(progress: ScanProgress) async
    func search(query: String) async -> [OCRSearchResult]
    func cancelIndexing() async
}

// MARK: - Helpers

private actor OCRBatchCollector {
    private var batch: [OCRTextData] = []
    private let visionStore: VisionCacheStore
    private let threshold: Int
    
    init(visionStore: VisionCacheStore, threshold: Int = 25) {
        self.visionStore = visionStore
        self.threshold = threshold
    }
    
    func add(_ item: OCRTextData) async throws {
        batch.append(item)
        if batch.count >= threshold {
            let toFlush = batch
            batch.removeAll()
            try await visionStore.upsertOCRTexts(toFlush)
        }
    }
    
    func flush() async throws {
        guard !batch.isEmpty else { return }
        let toFlush = batch
        batch.removeAll()
        try await visionStore.upsertOCRTexts(toFlush)
    }
}

private struct TextBoundingBox: Codable {
    let text: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - Service

actor TextRecognitionService: TextRecognitionServicing {
    private let visionStore: VisionCacheStore
    private let batchProcessor: BatchVisionProcessor
    private var currentTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.snapsort.vision", category: "ocr")
    
    init(visionStore: VisionCacheStore, batchProcessor: BatchVisionProcessor) {
        self.visionStore = visionStore
        self.batchProcessor = batchProcessor
    }
    
    func indexScreenshots(progress: ScanProgress) async {
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run { progress.reset(service: "Text Recognition", total: 0) }
            
            do {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.predicate = NSPredicate(
                    format: "mediaSubtype == %ld",
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                )
                
                var assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                var assetArray = (0..<assets.count).map { assets.object(at: $0) }
                
                if assetArray.isEmpty {
                    logger.info("No screenshot subtype found; falling back to all recent images")
                    let fallbackOptions = PHFetchOptions()
                    fallbackOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fallbackOptions.fetchLimit = 5000
                    assets = PHAsset.fetchAssets(with: .image, options: fallbackOptions)
                    assetArray = (0..<assets.count).map { assets.object(at: $0) }
                }
                
                guard !assetArray.isEmpty else {
                    await MainActor.run { progress.finish() }
                    return
                }
                
                let collector = OCRBatchCollector(visionStore: visionStore)
                
                try await batchProcessor.process(
                    assets: assetArray,
                    recordType: .ocrText,
                    chunkSize: 50,
                    targetSize: CGSize(width: 800, height: 800),
                    contentMode: .aspectFit,
                    deliveryMode: .fastFormat,
                    progress: progress,
                    serviceName: "TextRecognition"
                ) { asset, image in
                    do {
                        let result = try await self.recognizeText(in: image)
                        let data = OCRTextData(
                            assetLocalIdentifier: asset.localIdentifier,
                            extractedText: result.text,
                            textBoundingBoxes: result.boundingBoxesData,
                            ocrConfidence: result.confidence
                        )
                        try await collector.add(data)
                    } catch {
                        self.logger.error("OCR failed for \(asset.localIdentifier): \(error.localizedDescription)")
                    }
                }
                
                try await collector.flush()
                await MainActor.run { progress.finish() }
                
            } catch {
                logger.error("OCR indexing failed: \(error.localizedDescription)")
                await MainActor.run { progress.finish() }
            }
        }
        
        self.currentTask = task
        _ = await task.value
        self.currentTask = nil
    }
    
    func search(query: String) async -> [OCRSearchResult] {
        let rawResults = await visionStore.searchOCR(query: query)
        
        return rawResults.map { record in
            let snippet = self.makeSnippet(text: record.text, query: query)
            return OCRSearchResult(
                assetLocalIdentifier: record.identifier,
                extractedText: record.text,
                snippet: snippet,
                confidence: record.confidence
            )
        }.sorted { $0.confidence > $1.confidence }
    }
    
    func cancelIndexing() async {
        currentTask?.cancel()
        currentTask = nil
        logger.info("OCR indexing cancelled")
    }
    
    // MARK: - Private
    
    private func recognizeText(in image: UIImage) async throws -> (text: String, boundingBoxesData: Data, confidence: Float) {
        guard let cgImage = image.cgImage else {
            throw TextRecognitionError.cgImageConversionFailed
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw TextRecognitionError.visionRequestFailed(error)
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return ("", Data(), 0)
        }
        
        var texts: [String] = []
        var boundingBoxes: [TextBoundingBox] = []
        var confidences: [Float] = []
        
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            
            let text = candidate.string
            let confidence = candidate.confidence
            
            texts.append(text)
            confidences.append(confidence)
            
            let box = TextBoundingBox(
                text: text,
                x: Double(observation.boundingBox.origin.x),
                y: Double(observation.boundingBox.origin.y),
                width: Double(observation.boundingBox.width),
                height: Double(observation.boundingBox.height)
            )
            boundingBoxes.append(box)
        }
        
        let fullText = texts.joined(separator: "\n")
        let avgConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
        
        let boxesData: Data
        do {
            boxesData = try JSONEncoder().encode(boundingBoxes)
        } catch {
            boxesData = Data()
        }
        
        return (fullText, boxesData, avgConfidence)
    }
    
    private func makeSnippet(text: String, query: String) -> String {
        let terms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard let firstTerm = terms.first else {
            return String(text.prefix(80))
        }
        
        let lowerText = text.lowercased()
        guard let range = lowerText.range(of: firstTerm) else {
            return String(text.prefix(80))
        }
        
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 30, limitedBy: text.endIndex) ?? text.endIndex
        
        var snippet = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        if start > text.startIndex { snippet = "…" + snippet }
        if end < text.endIndex { snippet = snippet + "…" }
        
        return snippet
    }
}
