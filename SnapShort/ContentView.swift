//
//  ContentView.swift
//  SnapShort
//

import SwiftUI
import Photos
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var photoLibrary = PhotoLibraryManager()
    
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showSaveAlert: Bool = false
    @State private var customFileName: String = ""
    @State private var showSettings = false
    
    private let spacing: CGFloat = 5
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
    }
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // MARK: Header
                    HStack(spacing: 12) {
                        Text(AppInfo.appName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: "#000D5F"))
                        
                        Spacer()
                        
                        Button {
                            // Notification action
                        } label: {
                            Image(systemName: "bell")
                                .foregroundStyle(Color(hex: "#1A1A2E"))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "#F5F5F7"))
                                .clipShape(.circle)
                        }
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color(hex: "#1A1A2E"))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "#F5F5F7"))
                                .clipShape(.circle)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: Search Bar
                    HStack(spacing: 16) {
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color(hex: "#757686"))
                            }
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color(hex: "#757686"))
                        }
                        
                        TextField("Search your photos...", text: $viewModel.searchQuery)
                            .font(.system(size: 18))
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .onSubmit {
                                viewModel.performSearch()
                            }
                        
                        Button {
                            // microphone action
                        } label: {
                            Image(systemName: "mic")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color(hex: "#4A5FE8"))
                        }
                        
                        if let image = pickedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                
                                Button {
                                    pickedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.primary)
                                }
                            }
                        } else {
                            PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color(hex: "#4A5FE8"))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedPickerItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        await MainActor.run {
                                            self.pickedImage = uiImage
                                            self.customFileName = "Photo_\(Int(Date().timeIntervalSince1970))"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.white)
                    )
                    .padding(.horizontal, 24)
                    .shadow(
                        color: .black.opacity(0.06),
                        radius: 15,
                        y: 5
                    )
                    
                    // MARK: Action Buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ActionButton(
                                title: "Find Duplicates",
                                icon: "doc.on.doc",
                                color: Color(hex: "#4A5FE8")
                            ) {
                                viewModel.startDuplicateScan()
                            }
                            
                            ActionButton(
                                title: "Index Text",
                                icon: "text.magnifyingglass",
                                color: Color(hex: "#0A9396")
                            ) {
                                viewModel.startOCRIndexing()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    
                    // MARK: Main Content
                    if viewModel.activeSearch {
                        searchResultsView
                    } else {
                        photoGridView
                    }
                }
                
                // MARK: Progress Overlay
                if viewModel.isScanning, let progress = viewModel.scanProgress {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Text(viewModel.scanServiceName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        ProgressView(value: progress.fractionCompleted)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(width: 200)
                        
                        Text("\(progress.processedCount) / \(progress.totalCount)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if progress.estimatedSecondsRemaining > 0 {
                            Text("~\(Int(progress.estimatedSecondsRemaining))s remaining")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Button("Cancel") {
                            viewModel.cancelScan()
                        }
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1A1A2E").opacity(0.95))
                    )
                }
            }
            .background(Color(hex: "#FAFAFA"))
            .onAppear {
                settings.requestPhotosPermission()
            }
            .onChange(of: settings.hasPhotosAccess, initial: true) { _, hasAccess in
                if hasAccess {
                    photoLibrary.fetchPhotos()
                }
            }
            .alert("Save As", isPresented: $showSaveAlert) {
                TextField("Enter file name", text: $customFileName)
                
                Button("Save to Documents") {
                    if let pickedImage {
                        HelperFunctions.saveToDocuments(image: pickedImage, name: customFileName)
                    }
                    selectedPickerItem = nil
                }
                
                Button("Save to Camera Roll") {
                    if let pickedImage {
                        HelperFunctions.saveToPhotoLibrary(image: pickedImage)
                    }
                    selectedPickerItem = nil
                }
                
                Button("Cancel", role: .cancel) {
                    selectedPickerItem = nil
                }
            } message: {
                Text("Choose a name and location to save this image.")
            }
            .sheet(isPresented: $viewModel.showDuplicateResults) {
                DuplicateResultsView(clusters: viewModel.duplicateClusters)
            }
            .alert(isPresented: .constant(viewModel.scanError != nil)) {
                Alert(
                    title: Text("Scan Complete"),
                    message: Text(viewModel.scanError ?? ""),
                    dismissButton: .default(Text("OK")) {
                        viewModel.scanError = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Photo Grid
    
    private var photoGridView: some View {
        ScrollView(.vertical) {
            if let assets = photoLibrary.assets {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(0..<assets.count, id: \.self) { index in
                        let asset = assets.object(at: index)
                        PhotoThumbnailView(asset: asset)
                    }
                }
                .padding(.horizontal, spacing)
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .padding()
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "#757686"))
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#757686"))
                    Text("Try indexing text first, or use different keywords.")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#757686").opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 80)
            } else {
                List(viewModel.searchResults) { result in
                    SearchResultRow(result: result)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResultItem
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView().scaleEffect(0.7))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(Color(hex: "#1A1A2E"))
                
                Text(result.subtitle)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundStyle(Color(hex: "#757686"))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .task {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [result.assetLocalIdentifier], options: nil)
        guard let first = asset.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: first,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }
    }
}

// MARK: - Duplicate Results View

struct DuplicateResultsView: View {
    let clusters: [DuplicateCluster]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(clusters) { cluster in
                    DuplicateClusterRow(cluster: cluster)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Duplicates Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DuplicateClusterRow: View {
    let cluster: DuplicateCluster
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundStyle(Color(hex: "#4A5FE8"))
                Text("\(cluster.assetIdentifiers.count) similar photos")
                    .font(.headline)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cluster.assetIdentifiers, id: \.self) { id in
                        DuplicateThumbnail(
                            identifier: id,
                            isRecommended: id == cluster.recommendedKeepIdentifier
                        )
                    }
                }
            }
            
            if let keepId = cluster.recommendedKeepIdentifier {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Recommended keep")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct DuplicateThumbnail: View {
    let identifier: String
    let isRecommended: Bool
    @State private var image: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecommended ? Color.green : Color.clear, lineWidth: 3)
            )
            
            if isRecommended {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.green)
                    .clipShape(Circle())
                    .offset(x: -4, y: 4)
            }
        }
        .task {
            loadImage()
        }
    }
    
    private func loadImage() {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let first = asset.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: first,
            targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .task(id: asset.localIdentifier) {
            loadImage()
        }
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: 120 * scale, height: 120 * scale)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { fetchedImage, _ in
            if let fetchedImage {
                DispatchQueue.main.async {
                    self.image = fetchedImage
                }
            }
        }
    }
}
