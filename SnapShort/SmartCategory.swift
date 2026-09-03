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
    case food        = "Food & Drinks"
    case people      = "People"
    case animals     = "Animals"
    case travel      = "Travel"
    case nature      = "Nature"
    case work        = "Work & Education"
    case vehicles    = "Vehicles"
    case fitness     = "Health & Fitness"
    case home        = "Home & Shopping"
    case custom      = "My Categories"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all:         return "square.grid.2x2.fill"
        case .documents:   return "doc.text.fill"
        case .screenshots: return "iphone"
        case .food:        return "fork.knife"
        case .people:      return "person.2.fill"
        case .animals:     return "pawprint.fill"
        case .travel:      return "airplane"
        case .nature:      return "leaf.fill"
        case .work:        return "briefcase.fill"
        case .vehicles:    return "car.fill"
        case .fitness:     return "figure.run"
        case .home:        return "house.fill"
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
        // Documents & Finance
        case "receipts":
            return [Color(hex: "#FF5E62"), Color(hex: "#FF9966")] // Vibrant Coral Sunset
        case "finance":
            return [Color(hex: "#0575E6"), Color(hex: "#00F260")] // Electric Blue to Emerald
        case "invoices":
            return [Color(hex: "#4E54C8"), Color(hex: "#8F94FB")] // Royal Indigo Lavender
        case "ids":
            return [Color(hex: "#2193B0"), Color(hex: "#6DD5ED")] // Crisp Azure Cyan
        case "contracts":
            return [Color(hex: "#8A2387"), Color(hex: "#E94057")] // Deep Magenta Coral
        case "tickets":
            return [Color(hex: "#F97316"), Color(hex: "#FBBF24")] // Vibrant Amber Gold
        case "resumes":
            return [Color(hex: "#11998E"), Color(hex: "#38EF7D")] // Mint to Fresh Green
        case "business_cards":
            return [Color(hex: "#3A7BD5"), Color(hex: "#3A6073")] // Steel Blue
        case "coupons":
            return [Color(hex: "#ED213A"), Color(hex: "#93291E")] // Ruby Red
        case "qrcodes":
            return [Color(hex: "#2C3E50"), Color(hex: "#4CA1AF")] // Deep Charcoal to Slate
            
        // Screenshots & Digital
        case "app_screenshots":
            return [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")] // SnapShort Signature Purple
        case "chats":
            return [Color(hex: "#00B09B"), Color(hex: "#96C93D")] // WhatsApp Fresh Green
        case "webpages":
            return [Color(hex: "#0072FF"), Color(hex: "#00C6FF")] // Safari Cyan Blue
        case "memes":
            return [Color(hex: "#F7971E"), Color(hex: "#FFD200")] // Joyful Sunshine Yellow
        case "code":
            return [Color(hex: "#1F1C2C"), Color(hex: "#928DAB")] // Dark Cyber Matrix
        case "wallpapers":
            return [Color(hex: "#8E2DE2"), Color(hex: "#4A00E0")] // Cosmic Purple
        case "gaming":
            return [Color(hex: "#7F00FF"), Color(hex: "#E100FF")] // Neon Cyber Violet
        case "errors":
            return [Color(hex: "#FF416C"), Color(hex: "#FF4B2B")] // Warning Flame Red
            
        // Food & Drinks
        case "food":
            return [Color(hex: "#FF416C"), Color(hex: "#FFA07A")] // Tasty Coral
        case "recipes":
            return [Color(hex: "#F7971E"), Color(hex: "#FF7730")] // Kitchen Warm Flame
        case "coffee":
            return [Color(hex: "#795548"), Color(hex: "#C5A059")] // Rich Mocha Cream
        case "desserts":
            return [Color(hex: "#F72585"), Color(hex: "#FF758C")] // Candy Strawberry Pink
        case "groceries":
            return [Color(hex: "#56AB2F"), Color(hex: "#A8E063")] // Fresh Organic Green
        case "drinks":
            return [Color(hex: "#8A2387"), Color(hex: "#E94057")] // Sangria Wine
            
        // People & Events
        case "selfies":
            return [Color(hex: "#FF758C"), Color(hex: "#FF7EB3")] // Glowing Peach Pink
        case "family":
            return [Color(hex: "#FA709A"), Color(hex: "#FEE140")] // Warm Sunset Coral
        case "kids":
            return [Color(hex: "#4FACFE"), Color(hex: "#00F2FE")] // Playful Aqua Sky
        case "weddings":
            return [Color(hex: "#D4B5FF"), Color(hex: "#8950FC")] // Elegant Lavender
        case "fashion":
            return [Color(hex: "#FF9A8B"), Color(hex: "#FF6A88")] // Runway Rose
        case "shoes":
            return [Color(hex: "#38EF7D"), Color(hex: "#11998E")] // Sporty Mint
        case "jewelry":
            return [Color(hex: "#F6D365"), Color(hex: "#FDA085")] // Sparkling Gold
            
        // Pets & Animals
        case "dogs":
            return [Color(hex: "#F39060"), Color(hex: "#FFB03A")] // Golden Pup
        case "cats":
            return [Color(hex: "#8E9EAB"), Color(hex: "#EEF2F3")] // Silvery Whisker
        case "birds":
            return [Color(hex: "#00C6FF"), Color(hex: "#0072FF")] // Sky Feather Blue
        case "wildlife":
            return [Color(hex: "#134E5E"), Color(hex: "#71B280")] // Safari Emerald
            
        // Travel & Places
        case "flights":
            return [Color(hex: "#00C6FB"), Color(hex: "#005BEA")] // Aero Sky
        case "beaches":
            return [Color(hex: "#00F2FE"), Color(hex: "#4FACFE")] // Caribbean Aqua
        case "mountains":
            return [Color(hex: "#434343"), Color(hex: "#8999A6")] // High Alpine
        case "hotels":
            return [Color(hex: "#C79081"), Color(hex: "#DFA57D")] // Luxury Hotel Sand
        case "landmarks":
            return [Color(hex: "#F3A183"), Color(hex: "#ECA1FE")] // Heritage Peach-Violet
        case "cities":
            return [Color(hex: "#2B5876"), Color(hex: "#4E4376")] // Twilight Metropolis
            
        // Nature & Plants
        case "sunsets":
            return [Color(hex: "#FF4E50"), Color(hex: "#F9D423")] // Golden Sunset
        case "forests":
            return [Color(hex: "#0B8793"), Color(hex: "#360033")] // Mystic Deep Woods
        case "flowers":
            return [Color(hex: "#F857A6"), Color(hex: "#FF5858")] // Blossom Pink
        case "plants":
            return [Color(hex: "#11998E"), Color(hex: "#38EF7D")] // Botanical Leaf
            
        // Work & Education
        case "books":
            return [Color(hex: "#667EEA"), Color(hex: "#764BA2")] // Library Indigo
        case "presentations":
            return [Color(hex: "#1D976C"), Color(hex: "#93F9B9")] // High-Impact Green
        case "notes":
            return [Color(hex: "#F7971E"), Color(hex: "#FFD200")] // Post-it Amber
        case "certificates":
            return [Color(hex: "#F2994A"), Color(hex: "#F2C94C")] // Honor Gold
            
        // Vehicles & Transport
        case "cars":
            return [Color(hex: "#EB3349"), Color(hex: "#F45C43")] // Sports Car Red
        case "bikes":
            return [Color(hex: "#00B4DB"), Color(hex: "#0083B0")] // Speed Turquoise
        case "boats":
            return [Color(hex: "#1A2980"), Color(hex: "#26D0CE")] // Deep Sea to Aqua
            
        // Health & Fitness
        case "fitness":
            return [Color(hex: "#FF416C"), Color(hex: "#8A2387")] // Power Workout Fusion
        case "medical":
            return [Color(hex: "#00C6FF"), Color(hex: "#0072FF")] // Clean Medical Blue
            
        // Home & Shopping
        case "interiors":
            return [Color(hex: "#8E54E9"), Color(hex: "#4776E6")] // Modern Living
        case "shopping":
            return [Color(hex: "#F857A6"), Color(hex: "#FF5858")] // Hot Deal Pink
            
        // Default or Custom Categories
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

// MARK: - All 56 Preset Categories

extension SmartCategory {
    static let presets: [SmartCategory] = [
        
        // MARK: Documents & Finance (10)
        SmartCategory(id: "receipts", name: "Receipts", emoji: "🧾", icon: "doc.text.fill",
            colorHex: "#E76F51", group: .documents,
            visionTags: ["document", "paper"],
            ocrKeywords: ["total", "tax", "subtotal", "receipt", "paid", "invoice", "$", "€", "₹", "amount"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "finance", name: "Finance & Banking", emoji: "💳", icon: "creditcard.fill",
            colorHex: "#2A9D8F", group: .documents,
            visionTags: ["document"],
            ocrKeywords: ["account", "balance", "transfer", "bank", "payment", "statement", "wallet", "paypal", "upi", "neft", "rtgs"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "invoices", name: "Invoices & Bills", emoji: "📄", icon: "newspaper.fill",
            colorHex: "#264653", group: .documents,
            visionTags: ["document", "paper"],
            ocrKeywords: ["invoice", "bill", "due date", "amount due", "billing", "payable", "overdue"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "ids", name: "IDs & Passports", emoji: "🪪", icon: "person.text.rectangle.fill",
            colorHex: "#457B9D", group: .documents,
            visionTags: ["document", "card"],
            ocrKeywords: ["passport", "license", "identity", "national id", "driving", "dob", "expiry", "nationality", "aadhar", "pan"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "contracts", name: "Contracts & Legal", emoji: "📝", icon: "signature",
            colorHex: "#6D6875", group: .documents,
            visionTags: ["document"],
            ocrKeywords: ["agreement", "terms", "conditions", "contract", "signed", "clause", "party", "witness", "legal", "hereby"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "tickets", name: "Tickets & Passes", emoji: "🎫", icon: "ticket.fill",
            colorHex: "#F4A261", group: .documents,
            visionTags: ["document"],
            ocrKeywords: ["boarding pass", "flight", "gate", "seat", "ticket", "admit one", "booking", "pnr", "confirmation"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "resumes", name: "Resumes & CVs", emoji: "💼", icon: "doc.person.fill",
            colorHex: "#2D6A4F", group: .documents,
            visionTags: ["document"],
            ocrKeywords: ["resume", "curriculum vitae", "cv", "education", "experience", "skills", "employment", "objective", "references"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "business_cards", name: "Business Cards", emoji: "📇", icon: "person.crop.square.fill",
            colorHex: "#40916C", group: .documents,
            visionTags: ["card"],
            ocrKeywords: ["tel:", "email:", "ceo", "manager", "director", "www.", "co.", "ltd", "pvt"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "coupons", name: "Coupons & Vouchers", emoji: "🏷️", icon: "tag.fill",
            colorHex: "#D62828", group: .documents,
            visionTags: [],
            ocrKeywords: ["coupon", "promo code", "discount", "voucher", "valid until", "% off", "cashback", "offer"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "qrcodes", name: "QR & Barcodes", emoji: "🔲", icon: "qrcode",
            colorHex: "#333333", group: .documents,
            visionTags: ["qrcode", "barcode"],
            ocrKeywords: ["scan", "qr"],
            isCustom: false, photoCount: 0),
        
        // MARK: Screenshots & Digital (8)
        SmartCategory(id: "app_screenshots", name: "App UI & Settings", emoji: "📱", icon: "iphone",
            colorHex: "#4A5FE8", group: .screenshots,
            visionTags: [],
            ocrKeywords: ["settings", "notification", "allow", "deny", "enable", "disable", "toggle", "home"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "chats", name: "Chats & Messages", emoji: "💬", icon: "bubble.left.and.bubble.right.fill",
            colorHex: "#25D366", group: .screenshots,
            visionTags: [],
            ocrKeywords: ["whatsapp", "telegram", "imessage", "today", "yesterday", "delivered", "typing", "read", "seen"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "webpages", name: "Webpages & Articles", emoji: "🌐", icon: "safari.fill",
            colorHex: "#0096FF", group: .screenshots,
            visionTags: [],
            ocrKeywords: ["https://", "www.", "article", "subscribe", "share", "cookies", "read more", "click here"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "memes", name: "Memes & Funny", emoji: "😂", icon: "face.smiling.inverse",
            colorHex: "#FFD60A", group: .screenshots,
            visionTags: ["meme", "comic"],
            ocrKeywords: ["lol", "haha", "bruh", "literally", "me when", "nobody:", "my mom"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "code", name: "Code & Terminal", emoji: "💻", icon: "chevron.left.forwardslash.chevron.right",
            colorHex: "#1B1B1B", group: .screenshots,
            visionTags: [],
            ocrKeywords: ["func", "class", "import", "const", "console.log", "return", "git", "bash", "def", "var", "let", "print("],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "wallpapers", name: "Wallpapers", emoji: "🖼️", icon: "photo.artframe",
            colorHex: "#9B72CF", group: .screenshots,
            visionTags: ["landscape", "nature", "abstract"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "gaming", name: "Gaming", emoji: "🎮", icon: "gamecontroller.fill",
            colorHex: "#7B2FBE", group: .screenshots,
            visionTags: ["game"],
            ocrKeywords: ["score", "level", "game", "fps", "hp", "xp", "victory", "gameplay", "respawn", "kill"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "errors", name: "Error Screens", emoji: "⚠️", icon: "exclamationmark.triangle.fill",
            colorHex: "#FF4D4D", group: .screenshots,
            visionTags: [],
            ocrKeywords: ["error", "404", "failed", "exception", "fatal", "crash", "warning", "unable to", "oops", "something went wrong"],
            isCustom: false, photoCount: 0),
        
        // MARK: Food & Drinks (6)
        SmartCategory(id: "food", name: "Fast Food & Meals", emoji: "🍔", icon: "fork.knife",
            colorHex: "#FF6B35", group: .food,
            visionTags: ["food", "meal", "dish", "pizza", "burger", "sandwich", "fries", "cuisine"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "recipes", name: "Recipes & Cooking", emoji: "🍳", icon: "frying.pan.fill",
            colorHex: "#E9C46A", group: .food,
            visionTags: ["food", "kitchen"],
            ocrKeywords: ["ingredients", "tsp", "tbsp", "cook time", "prep", "bake", "oven", "recipe", "serves", "minutes"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "coffee", name: "Coffee & Tea", emoji: "☕", icon: "cup.and.saucer.fill",
            colorHex: "#6F4E37", group: .food,
            visionTags: ["coffee", "tea", "cafe", "mug", "latte", "espresso", "cappuccino"],
            ocrKeywords: ["coffee", "latte", "espresso", "chai", "tea", "barista", "cafe"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "desserts", name: "Desserts & Bakery", emoji: "🍰", icon: "birthday.cake.fill",
            colorHex: "#F72585", group: .food,
            visionTags: ["dessert", "cake", "pastry", "cookie", "ice cream", "bakery", "chocolate"],
            ocrKeywords: ["dessert", "bakery", "sweet", "cake", "pastry"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "groceries", name: "Groceries & Produce", emoji: "🥗", icon: "carrot.fill",
            colorHex: "#57CC99", group: .food,
            visionTags: ["vegetable", "fruit", "grocery", "salad", "produce"],
            ocrKeywords: ["grocery", "supermarket", "vegetables", "fruits", "organic", "fresh"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "drinks", name: "Drinks & Cocktails", emoji: "🍷", icon: "wineglass.fill",
            colorHex: "#9D0208", group: .food,
            visionTags: ["wine", "beer", "cocktail", "alcohol", "beverage", "bar", "bottle", "drink"],
            ocrKeywords: ["cocktail", "wine", "beer", "alcohol", "spirits", "bar"],
            isCustom: false, photoCount: 0),
        
        // MARK: People & Events (7)
        SmartCategory(id: "selfies", name: "Selfies", emoji: "🤳", icon: "camera.fill",
            colorHex: "#FF69B4", group: .people,
            visionTags: ["selfie", "face", "portrait", "person"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "family", name: "Family & Groups", emoji: "👨‍👩‍👧", icon: "person.3.fill",
            colorHex: "#E76F51", group: .people,
            visionTags: ["people", "family", "crowd", "group"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "kids", name: "Kids & Babies", emoji: "👶", icon: "figure.and.child.holdinghands",
            colorHex: "#FBBF24", group: .people,
            visionTags: ["baby", "infant", "child", "toddler"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "weddings", name: "Weddings & Parties", emoji: "💍", icon: "sparkles",
            colorHex: "#C77DFF", group: .people,
            visionTags: ["wedding", "bride", "groom", "party", "celebration", "festival"],
            ocrKeywords: ["wedding", "reception", "ceremony", "birthday", "anniversary"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "fashion", name: "Fashion & Outfits", emoji: "👔", icon: "tshirt.fill",
            colorHex: "#E9C46A", group: .people,
            visionTags: ["clothing", "apparel", "dress", "outfit", "suit", "fashion", "jacket", "shirt"],
            ocrKeywords: ["outfit", "ootd", "fashion", "style", "wear"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "shoes", name: "Shoes & Sneakers", emoji: "👟", icon: "shoeprints.fill",
            colorHex: "#3A86FF", group: .people,
            visionTags: ["shoe", "sneaker", "footwear", "boots", "heels"],
            ocrKeywords: ["shoes", "sneakers", "footwear", "nike", "adidas"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "jewelry", name: "Jewelry & Watches", emoji: "💍", icon: "watch.analog",
            colorHex: "#FFD700", group: .people,
            visionTags: ["watch", "jewelry", "ring", "necklace", "bracelet", "earrings"],
            ocrKeywords: ["jewelry", "gold", "silver", "diamond", "watch", "ring"],
            isCustom: false, photoCount: 0),
        
        // MARK: Pets & Animals (4)
        SmartCategory(id: "dogs", name: "Dogs", emoji: "🐶", icon: "dog.fill",
            colorHex: "#8B4513", group: .animals,
            visionTags: ["dog", "canine", "puppy", "hound"],
            ocrKeywords: ["dog", "puppy", "pup", "canine"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "cats", name: "Cats", emoji: "🐱", icon: "cat.fill",
            colorHex: "#708090", group: .animals,
            visionTags: ["cat", "feline", "kitten", "tabby"],
            ocrKeywords: ["cat", "kitten", "feline"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "birds", name: "Birds", emoji: "🐦", icon: "bird.fill",
            colorHex: "#87CEEB", group: .animals,
            visionTags: ["bird", "parrot", "eagle", "sparrow", "feather"],
            ocrKeywords: ["bird", "parrot", "eagle"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "wildlife", name: "Wildlife & Animals", emoji: "🦁", icon: "pawprint.fill",
            colorHex: "#228B22", group: .animals,
            visionTags: ["animal", "wildlife", "mammal", "horse", "fish", "reptile"],
            ocrKeywords: ["animal", "wildlife", "zoo", "safari"],
            isCustom: false, photoCount: 0),
        
        // MARK: Travel & Places (6)
        SmartCategory(id: "flights", name: "Flights & Airports", emoji: "✈️", icon: "airplane",
            colorHex: "#48CAE4", group: .travel,
            visionTags: ["airport", "airplane", "runway", "terminal", "aircraft"],
            ocrKeywords: ["boarding pass", "flight", "gate", "departure", "arrival", "pnr", "airline"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "beaches", name: "Beaches & Oceans", emoji: "🏖️", icon: "water.waves",
            colorHex: "#0096FF", group: .travel,
            visionTags: ["beach", "ocean", "sea", "sand", "coast", "shore", "tropical"],
            ocrKeywords: ["beach", "ocean", "resort", "tropical"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "mountains", name: "Mountains & Hiking", emoji: "⛰️", icon: "mountain.2.fill",
            colorHex: "#556B2F", group: .travel,
            visionTags: ["mountain", "hill", "hiking", "valley", "peak", "summit", "trail"],
            ocrKeywords: ["hiking", "trekking", "trail", "summit", "mountain"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "hotels", name: "Hotels & Resorts", emoji: "🏨", icon: "bed.double.fill",
            colorHex: "#C8A96E", group: .travel,
            visionTags: ["hotel", "resort", "lobby", "pool", "room"],
            ocrKeywords: ["hotel", "resort", "check in", "check out", "reservation", "booking"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "landmarks", name: "Landmarks & Monuments", emoji: "🏛️", icon: "building.columns.fill",
            colorHex: "#E9C46A", group: .travel,
            visionTags: ["landmark", "monument", "statue", "temple", "church", "tower", "attraction"],
            ocrKeywords: ["monument", "heritage", "historic", "museum"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "cities", name: "Cities & Skylines", emoji: "🌆", icon: "building.2.fill",
            colorHex: "#3D405B", group: .travel,
            visionTags: ["city", "skyline", "skyscraper", "downtown", "urban", "street"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        // MARK: Nature & Plants (4)
        SmartCategory(id: "sunsets", name: "Sunsets & Sunrises", emoji: "🌅", icon: "sunset.fill",
            colorHex: "#FF6B35", group: .nature,
            visionTags: ["sunset", "sunrise", "dusk", "dawn", "golden hour", "sky"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "forests", name: "Forests & Trees", emoji: "🌲", icon: "tree.fill",
            colorHex: "#1B4332", group: .nature,
            visionTags: ["forest", "woods", "tree", "park", "jungle", "pine"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "flowers", name: "Flowers & Gardens", emoji: "🌸", icon: "camera.macro",
            colorHex: "#F72585", group: .nature,
            visionTags: ["flower", "rose", "garden", "flora", "petal", "tulip", "blossom"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "plants", name: "Houseplants", emoji: "🪴", icon: "leaf.fill",
            colorHex: "#52B788", group: .nature,
            visionTags: ["plant", "houseplant", "succulent", "cactus", "botanical"],
            ocrKeywords: [],
            isCustom: false, photoCount: 0),
        
        // MARK: Work & Education (4)
        SmartCategory(id: "books", name: "Books & Study", emoji: "📚", icon: "book.closed.fill",
            colorHex: "#8B5CF6", group: .work,
            visionTags: ["book", "textbook", "library"],
            ocrKeywords: ["chapter", "homework", "textbook", "notebook", "study", "library", "exam", "assignment"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "presentations", name: "Presentations & Slides", emoji: "📊", icon: "chart.bar.xaxis",
            colorHex: "#0369A1", group: .work,
            visionTags: ["presentation", "chart", "diagram"],
            ocrKeywords: ["agenda", "slide", "quarter", "revenue", "chart", "diagram", "presentation", "kpi", "q1", "q2", "q3", "q4"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "notes", name: "Whiteboards & Notes", emoji: "🧑‍🏫", icon: "pencil.and.ruler.fill",
            colorHex: "#F59E0B", group: .work,
            visionTags: ["whiteboard", "chalkboard"],
            ocrKeywords: ["whiteboard", "handwriting", "notes", "bullet", "todo", "task list"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "certificates", name: "Certificates & Awards", emoji: "🏆", icon: "trophy.fill",
            colorHex: "#F59E0B", group: .work,
            visionTags: [],
            ocrKeywords: ["certificate", "award", "achievement", "diploma", "honors", "presented to", "congratulations"],
            isCustom: false, photoCount: 0),
        
        // MARK: Vehicles & Transport (3)
        SmartCategory(id: "cars", name: "Cars & Autos", emoji: "🚗", icon: "car.fill",
            colorHex: "#DC2626", group: .vehicles,
            visionTags: ["car", "automobile", "vehicle", "sedan", "suv"],
            ocrKeywords: ["car", "vehicle", "auto", "driving", "license plate"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "bikes", name: "Bikes & Motorcycles", emoji: "🏍️", icon: "bicycle",
            colorHex: "#16A34A", group: .vehicles,
            visionTags: ["motorcycle", "motorbike", "bicycle", "bike", "scooter"],
            ocrKeywords: ["motorcycle", "bicycle", "bike", "cycling"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "boats", name: "Boats & Ships", emoji: "🚢", icon: "ferry.fill",
            colorHex: "#1E40AF", group: .vehicles,
            visionTags: ["boat", "ship", "yacht", "vessel", "cruise", "ferry"],
            ocrKeywords: ["cruise", "ferry", "ship", "harbor", "port"],
            isCustom: false, photoCount: 0),
        
        // MARK: Health & Fitness (2)
        SmartCategory(id: "fitness", name: "Gym & Workouts", emoji: "🏋️", icon: "figure.run",
            colorHex: "#DC2626", group: .fitness,
            visionTags: ["gym", "fitness", "workout", "dumbbell"],
            ocrKeywords: ["gym", "fitness", "workout", "reps", "sets", "calories", "running", "exercise", "bpm", "heartrate"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "medical", name: "Medical & Pharmacy", emoji: "💊", icon: "cross.case.fill",
            colorHex: "#0EA5E9", group: .fitness,
            visionTags: ["medical", "pharmacy", "hospital"],
            ocrKeywords: ["rx", "prescription", "clinic", "hospital", "medicine", "dose", "pharmacy", "tablet", "capsule", "mg"],
            isCustom: false, photoCount: 0),
        
        // MARK: Home & Shopping (2)
        SmartCategory(id: "interiors", name: "Interior & Furniture", emoji: "🛋️", icon: "sofa.fill",
            colorHex: "#78350F", group: .home,
            visionTags: ["interior", "living room", "bedroom", "furniture", "couch", "decor", "kitchen"],
            ocrKeywords: ["interior", "furniture", "bedroom", "living room", "decor", "renovation"],
            isCustom: false, photoCount: 0),
        
        SmartCategory(id: "shopping", name: "Shopping & Orders", emoji: "🛍️", icon: "bag.fill",
            colorHex: "#7C3AED", group: .home,
            visionTags: ["store", "product", "shopping"],
            ocrKeywords: ["order placed", "shipped", "tracking", "amazon", "cart", "checkout", "delivery", "flipkart", "wishlist"],
            isCustom: false, photoCount: 0)
    ]
}
