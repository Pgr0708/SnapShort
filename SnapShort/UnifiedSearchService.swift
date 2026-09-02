//
//  UnifiedSearchService.swift
//  SnapShort
//

import Foundation

// MARK: - Result Types

enum SearchResultSource {
    case ocr
    case contentTag
}

struct SearchResultItem: Identifiable {
    let id = UUID()
    let assetLocalIdentifier: String
    let title: String
    let subtitle: String
    let relevanceScore: Double
    let source: SearchResultSource
}

struct UnifiedSearchResults {
    let ocrMatches: [OCRSearchResult]
    let combinedAndDeduplicated: [SearchResultItem]
}

// MARK: - Protocol

protocol UnifiedSearchServicing {
    func search(query: String) async -> UnifiedSearchResults
}

// MARK: - Service

actor UnifiedSearchService: UnifiedSearchServicing {
    private let textRecognitionService: TextRecognitionServicing
    
    init(textRecognitionService: TextRecognitionServicing) {
        self.textRecognitionService = textRecognitionService
    }
    
    func search(query: String) async -> UnifiedSearchResults {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return UnifiedSearchResults(ocrMatches: [], combinedAndDeduplicated: [])
        }
        
        let ocrResults = await textRecognitionService.search(query: normalized)
        
        let combined = deduplicateAndRank(ocrResults: ocrResults)
        
        return UnifiedSearchResults(
            ocrMatches: ocrResults,
            combinedAndDeduplicated: combined
        )
    }
    
    // MARK: - Private
    
    private func deduplicateAndRank(ocrResults: [OCRSearchResult]) -> [SearchResultItem] {
        var itemsById: [String: SearchResultItem] = [:]
        
        for ocr in ocrResults {
            let relevance = Double(ocr.confidence)
            
            if let existing = itemsById[ocr.assetLocalIdentifier] {
                // Merge: boost relevance if found in multiple sources (future-proof)
                let merged = SearchResultItem(
                    assetLocalIdentifier: existing.assetLocalIdentifier,
                    title: existing.title,
                    subtitle: existing.subtitle,
                    relevanceScore: max(existing.relevanceScore, relevance),
                    source: existing.source
                )
                itemsById[ocr.assetLocalIdentifier] = merged
            } else {
                let item = SearchResultItem(
                    assetLocalIdentifier: ocr.assetLocalIdentifier,
                    title: ocr.snippet,
                    subtitle: ocr.extractedText,
                    relevanceScore: relevance,
                    source: .ocr
                )
                itemsById[ocr.assetLocalIdentifier] = item
            }
        }
        
        return itemsById.values.sorted { $0.relevanceScore > $1.relevanceScore }
    }
}
