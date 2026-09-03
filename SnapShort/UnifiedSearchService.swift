//
//  UnifiedSearchService.swift
//  SnapShort
//

import Foundation

// MARK: - Result Types

enum SearchResultSource {
    case ocr
    case contentTag
    case photoNote
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
    private let visionStore: VisionCacheStore
    
    init(textRecognitionService: TextRecognitionServicing, visionStore: VisionCacheStore) {
        self.textRecognitionService = textRecognitionService
        self.visionStore = visionStore
    }
    
    func search(query: String) async -> UnifiedSearchResults {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return UnifiedSearchResults(ocrMatches: [], combinedAndDeduplicated: [])
        }
        
        // Run OCR search + Notes search in parallel
        async let ocrResults = textRecognitionService.search(query: normalized)
        async let noteResults = visionStore.searchPhotoNotes(query: normalized)
        
        let (ocr, notes) = await (ocrResults, noteResults)
        
        let combined = deduplicateAndRank(ocrResults: ocr, noteResults: notes)
        
        return UnifiedSearchResults(
            ocrMatches: ocr,
            combinedAndDeduplicated: combined
        )
    }
    
    // MARK: - Private
    
    private func deduplicateAndRank(
        ocrResults: [OCRSearchResult],
        noteResults: [(identifier: String, matchedNote: String)]
    ) -> [SearchResultItem] {
        var itemsById: [String: SearchResultItem] = [:]
        
        // Add OCR results
        for ocr in ocrResults {
            let relevance = Double(ocr.confidence)
            if let existing = itemsById[ocr.assetLocalIdentifier] {
                let merged = SearchResultItem(
                    assetLocalIdentifier: existing.assetLocalIdentifier,
                    title: existing.title,
                    subtitle: existing.subtitle,
                    relevanceScore: max(existing.relevanceScore, relevance),
                    source: existing.source
                )
                itemsById[ocr.assetLocalIdentifier] = merged
            } else {
                itemsById[ocr.assetLocalIdentifier] = SearchResultItem(
                    assetLocalIdentifier: ocr.assetLocalIdentifier,
                    title: ocr.snippet,
                    subtitle: ocr.extractedText,
                    relevanceScore: relevance,
                    source: .ocr
                )
            }
        }
        
        // Add note results — give a high fixed relevance since user wrote the note intentionally
        for note in noteResults {
            if let existing = itemsById[note.identifier] {
                // Boost existing item's score
                let boosted = SearchResultItem(
                    assetLocalIdentifier: existing.assetLocalIdentifier,
                    title: existing.title,
                    subtitle: "📝 " + note.matchedNote,
                    relevanceScore: min(existing.relevanceScore + 0.3, 1.0),
                    source: .photoNote
                )
                itemsById[note.identifier] = boosted
            } else {
                itemsById[note.identifier] = SearchResultItem(
                    assetLocalIdentifier: note.identifier,
                    title: note.matchedNote,
                    subtitle: "📝 From your notes",
                    relevanceScore: 0.85,   // high relevance — user explicitly wrote this
                    source: .photoNote
                )
            }
        }
        
        return itemsById.values.sorted { $0.relevanceScore > $1.relevanceScore }
    }
}
