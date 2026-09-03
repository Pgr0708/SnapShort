//
//  SmartCategory.swift
//  SnapShort
//

import SwiftUI

// MARK: - Category Group

enum CategoryGroup: String, CaseIterable, Identifiable {
    case all         = "All"
    case documents   = "Documents"
    case screenshots = "Screenshots"
    case lifestyle   = "Lifestyle"
    case people      = "People"
    case nature      = "Nature"
    case custom      = "My Categories"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all:         return "square.grid.2x2.fill"
        case .documents:   return "doc.text.fill"
        case .screenshots: return "iphone"
        case .lifestyle:   return "heart.fill"
        case .people:      return "person.2.fill"
        case .nature:      return "leaf.fill"
        case .custom:      return "star.fill"
        }
    }
}

// MARK: - Smart Category Model

struct SmartCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let icon: String           // SF Symbol
    let colorHex: String
    let group: CategoryGroup
    let visionTags: [String]   // Apple Vision classifier labels
    let ocrKeywords: [String]  // Text that must appear in OCR
    let isCustom: Bool
    var photoCount: Int
    
    // Custom category initializer
    static func custom(id: String, name: String, icon: String, colorHex: String, keywords: [String]) -> SmartCategory {
        SmartCategory(
            id: id, name: name, emoji: "⭐", icon: icon,
            colorHex: colorHex, group: .custom,
            visionTags: [], ocrKeywords: keywords,
            isCustom: true, photoCount: 0
        )
    }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SmartCategory, rhs: SmartCategory) -> Bool { lhs.id == rhs.id }
    
    // MARK: - Curated Linear Gradients
    
    var gradientColors: [Color] {
        switch id {
        case "receipts":
            return [Color(hex: "#FF5E62"), Color(hex: "#FF9966")] // Coral Sunset
        case "chats":
            return [Color(hex: "#00B09B"), Color(hex: "#96C93D")] // WhatsApp Green
        case "ids":
            return [Color(hex: "#2193B0"), Color(hex: "#6DD5ED")] // Azure Cyan
        case "memes":
            return [Color(hex: "#F7971E"), Color(hex: "#FFD200")] // Sunshine Gold
        case "food":
            return [Color(hex: "#FF416C"), Color(hex: "#FFA07A")] // Flame
        case "selfies":
            return [Color(hex: "#FF758C"), Color(hex: "#FF7EB3")] // Rose Pink
        case "family":
            return [Color(hex: "#FA709A"), Color(hex: "#FEE140")] // Warm Coral
        case "pets":
            return [Color(hex: "#F39060"), Color(hex: "#FFB03A")] // Golden Amber
        case "travel":
            return [Color(hex: "#00C6FB"), Color(hex: "#005BEA")] // Sky Ocean
        case "notes":
            return [Color(hex: "#667EEA"), Color(hex: "#764BA2")] // Indigo Violet
        case "maps":
            return [Color(hex: "#11998E"), Color(hex: "#38EF7D")] // Map Fresh Mint
        case "qrcodes":
            return [Color(hex: "#2C3E50"), Color(hex: "#4CA1AF")] // Dark Slate Cyan
        case "wallpapers":
            return [Color(hex: "#8A2387"), Color(hex: "#F27121")] // Neon Magenta Sunset
        case "nature":
            return [Color(hex: "#56AB2F"), Color(hex: "#A8E063")] // Forest Lime
        case "fitness":
            return [Color(hex: "#F953C6"), Color(hex: "#B91D73")] // Electric Magenta
        case "shopping":
            return [Color(hex: "#FC5C7D"), Color(hex: "#6A82FB")] // Candy Purple
        case "screenshots":
            return [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")] // SnapShort Purple
        default:
            return fallbackGradient(for: colorHex)
        }
    }
    
    private func fallbackGradient(for hex: String) -> [Color] {
        switch hex.uppercased() {
        case "#4A5FE8": return [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")]
        case "#0A9396": return [Color(hex: "#0A9396"), Color(hex: "#94D2BD")]
        case "#E76F51": return [Color(hex: "#E76F51"), Color(hex: "#F4A261")]
        case "#F4A261": return [Color(hex: "#F4A261"), Color(hex: "#E76F51")]
        case "#2A9D8F": return [Color(hex: "#2A9D8F"), Color(hex: "#264653")]
        case "#264653": return [Color(hex: "#264653"), Color(hex: "#2A9D8F")]
        case "#E9C46A": return [Color(hex: "#E9C46A"), Color(hex: "#F4A261")]
        case "#6D6875": return [Color(hex: "#6D6875"), Color(hex: "#B5838D")]
        case "#D62828": return [Color(hex: "#D62828"), Color(hex: "#F77F00")]
        case "#7B2FBE": return [Color(hex: "#7B2FBE"), Color(hex: "#C77DFF")]
        case "#FF6B35": return [Color(hex: "#FF6B35"), Color(hex: "#F7C59F")]
        case "#40916C": return [Color(hex: "#40916C"), Color(hex: "#74C69D")]
        case "#457B9D": return [Color(hex: "#457B9D"), Color(hex: "#A8DADC")]
        case "#C77DFF": return [Color(hex: "#C77DFF"), Color(hex: "#7B2FBE")]
        case "#DC2626": return [Color(hex: "#DC2626"), Color(hex: "#F87171")]
        case "#0EA5E9": return [Color(hex: "#0EA5E9"), Color(hex: "#38BDF8")]
        case "#F59E0B": return [Color(hex: "#F59E0B"), Color(hex: "#FCD34D")]
        case "#1B4332": return [Color(hex: "#1B4332"), Color(hex: "#40916C")]
        case "#78350F": return [Color(hex: "#78350F"), Color(hex: "#B45309")]
        case "#374151": return [Color(hex: "#374151"), Color(hex: "#6B7280")]
        default:
            return [Color(hex: hex), Color(hex: hex).opacity(0.75)]
        }
    }
}

// MARK: - 10 Essential Curated Categories for iPhone Users

extension SmartCategory {
    static let presets: [SmartCategory] = [
        
        // 1. Receipts & Orders
        SmartCategory(
            id: "receipts",
            name: "Receipts & Orders",
            emoji: "🧾",
            icon: "doc.text.fill",
            colorHex: "#FF5E62",
            group: .documents,
            visionTags: ["document", "paper"],
            ocrKeywords: [
                "total", "tax", "subtotal", "receipt", "paid", "invoice",
                "$", "€", "₹", "amount", "order", "shipped", "amazon",
                "delivery", "tracking", "visa", "mastercard", "apple pay", "purchase"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 2. Chats & Messages
        SmartCategory(
            id: "chats",
            name: "Chats & Messages",
            emoji: "💬",
            icon: "bubble.left.and.bubble.right.fill",
            colorHex: "#00B09B",
            group: .screenshots,
            visionTags: [],
            ocrKeywords: [
                "whatsapp", "telegram", "imessage", "today", "yesterday",
                "delivered", "typing", "read", "seen", "message", "reply", "sent"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 3. IDs, Cards & Documents
        SmartCategory(
            id: "ids",
            name: "IDs, Cards & Docs",
            emoji: "🪪",
            icon: "person.text.rectangle.fill",
            colorHex: "#2193B0",
            group: .documents,
            visionTags: ["card", "document"],
            ocrKeywords: [
                "passport", "license", "identity", "national id", "driving",
                "dob", "expiry", "nationality", "aadhar", "pan", "bank", "account",
                "insurance", "valid through", "cardholder"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 4. Memes & Social Media
        SmartCategory(
            id: "memes",
            name: "Memes & Social",
            emoji: "😂",
            icon: "face.smiling.inverse",
            colorHex: "#F7971E",
            group: .screenshots,
            visionTags: ["meme", "comic"],
            ocrKeywords: [
                "lol", "haha", "bruh", "literally", "me when", "nobody:",
                "instagram", "tiktok", "twitter", "reddit", "likes", "comments",
                "followers", "share", "retweet", "post"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 5. Food & Dining
        SmartCategory(
            id: "food",
            name: "Food & Dining",
            emoji: "🍔",
            icon: "fork.knife",
            colorHex: "#FF416C",
            group: .lifestyle,
            visionTags: [
                "food", "meal", "dish", "pizza", "burger", "sandwich", "fries",
                "cuisine", "coffee", "latte", "cake", "dessert", "drink", "cocktail",
                "pastry", "pasta", "sushi", "salad", "breakfast", "dinner"
            ],
            ocrKeywords: ["menu", "cafe", "restaurant", "burger", "pizza", "coffee", "recipe"],
            isCustom: false,
            photoCount: 0
        ),
        
        // 6. Selfies & Portraits
        SmartCategory(
            id: "selfies",
            name: "Selfies & Portraits",
            emoji: "🤳",
            icon: "camera.fill",
            colorHex: "#FF758C",
            group: .people,
            visionTags: ["selfie", "face", "portrait", "person"],
            ocrKeywords: [],
            isCustom: false,
            photoCount: 0
        ),
        
        // 7. Friends & Family
        SmartCategory(
            id: "family",
            name: "Friends & Family",
            emoji: "👨‍👩‍👧",
            icon: "person.3.fill",
            colorHex: "#FA709A",
            group: .people,
            visionTags: ["people", "family", "crowd", "group", "baby", "child", "wedding", "party"],
            ocrKeywords: ["birthday", "wedding", "party", "anniversary", "celebration", "family"],
            isCustom: false,
            photoCount: 0
        ),
        
        // 8. Pets & Animals
        SmartCategory(
            id: "pets",
            name: "Pets & Animals",
            emoji: "🐶",
            icon: "pawprint.fill",
            colorHex: "#F39060",
            group: .lifestyle,
            visionTags: ["dog", "canine", "puppy", "hound", "cat", "feline", "kitten", "pet", "animal", "bird"],
            ocrKeywords: ["dog", "cat", "puppy", "kitten", "pet"],
            isCustom: false,
            photoCount: 0
        ),
        
        // 9. Travel & Vacations
        SmartCategory(
            id: "travel",
            name: "Travel & Vacations",
            emoji: "✈️",
            icon: "airplane",
            colorHex: "#00C6FB",
            group: .lifestyle,
            visionTags: [
                "airplane", "airport", "beach", "ocean", "sea", "sand", "mountain",
                "hiking", "hotel", "resort", "sunset", "sunrise", "skyline", "landmark",
                "pool", "scenic", "landscape", "monument"
            ],
            ocrKeywords: [
                "boarding pass", "flight", "gate", "seat", "departure", "arrival",
                "hotel", "resort", "booking", "reservation", "vacation", "trip"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 10. Notes & Reminders
        SmartCategory(
            id: "notes",
            name: "Notes & Reminders",
            emoji: "📝",
            icon: "note.text",
            colorHex: "#667EEA",
            group: .documents,
            visionTags: ["whiteboard", "chalkboard", "document", "paper"],
            ocrKeywords: [
                "notes", "todo", "task", "homework", "agenda", "meeting", "handwriting",
                "bullet", "reminder", "list", "sign", "notice", "schedule", "exam"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // --- Background / Secondary Categories ---
        // (Only shown automatically if ≥ 3 photos match)
        
        // 11. Maps & Navigation
        SmartCategory(
            id: "maps",
            name: "Maps & Navigation",
            emoji: "🗺️",
            icon: "map.fill",
            colorHex: "#11998E",
            group: .screenshots,
            visionTags: ["map"],
            ocrKeywords: [
                "google maps", "apple maps", "directions", "navigate", "route",
                "km", "miles", "eta", "turn left", "turn right", "uber", "ola",
                "your location", "traffic", "destination"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 12. QR Codes & Barcodes
        SmartCategory(
            id: "qrcodes",
            name: "QR & Barcodes",
            emoji: "🔳",
            icon: "qrcode",
            colorHex: "#2C3E50",
            group: .documents,
            visionTags: ["qr code", "barcode"],
            ocrKeywords: [
                "scan", "qr", "barcode", "upi", "gpay", "phonepay", "scan to pay",
                "scan me", "scan here", "scan this"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 13. Wallpapers & Art
        SmartCategory(
            id: "wallpapers",
            name: "Wallpapers & Art",
            emoji: "🎨",
            icon: "photo.artframe",
            colorHex: "#8A2387",
            group: .nature,
            visionTags: [
                "abstract", "illustration", "digital art", "wallpaper", "painting",
                "artwork", "graphic", "minimalism", "texture", "pattern"
            ],
            ocrKeywords: [],
            isCustom: false,
            photoCount: 0
        ),
        
        // 14. Nature & Outdoors
        SmartCategory(
            id: "nature",
            name: "Nature & Outdoors",
            emoji: "🌿",
            icon: "leaf.fill",
            colorHex: "#56AB2F",
            group: .nature,
            visionTags: [
                "nature", "tree", "forest", "flower", "plant", "garden",
                "sky", "cloud", "rain", "snow", "waterfall", "river",
                "field", "grass", "valley", "jungle", "park"
            ],
            ocrKeywords: [],
            isCustom: false,
            photoCount: 0
        ),
        
        // 15. Fitness & Workouts
        SmartCategory(
            id: "fitness",
            name: "Fitness & Workouts",
            emoji: "💪",
            icon: "figure.run",
            colorHex: "#F953C6",
            group: .lifestyle,
            visionTags: [
                "gym", "exercise", "yoga", "running", "cycling", "sports",
                "fitness", "weightlifting", "workout", "training"
            ],
            ocrKeywords: [
                "steps", "calories", "km run", "workout", "fitness", "gym",
                "apple fitness", "health", "bmi", "reps", "sets", "personal best"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 16. Shopping & Apps
        SmartCategory(
            id: "shopping",
            name: "Shopping & Apps",
            emoji: "🛍️",
            icon: "bag.fill",
            colorHex: "#FC5C7D",
            group: .screenshots,
            visionTags: [],
            ocrKeywords: [
                "add to cart", "buy now", "checkout", "wishlist", "offer",
                "discount", "sale", "% off", "flip kart", "flipkart", "meesho",
                "myntra", "ajio", "nykaa", "zomato", "swiggy", "app store"
            ],
            isCustom: false,
            photoCount: 0
        ),
        
        // 17. App Screenshots
        SmartCategory(
            id: "screenshots",
            name: "App Screenshots",
            emoji: "📱",
            icon: "iphone",
            colorHex: "#4A5FE8",
            group: .screenshots,
            visionTags: [],
            ocrKeywords: [
                "battery", "signal", "wi-fi", "settings", "notifications",
                "home screen", "lock screen"
            ],
            isCustom: false,
            photoCount: 0
        )
    ]
    
    /// Minimum number of photos a category needs before it is shown in the grid.
    /// Custom categories always show regardless.
    static let minimumPhotosToDisplay: Int = 3
}
