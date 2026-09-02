//
//  ContentView.swift
//  SnapShort
//
//  Created by Minaxi on 31/08/26.
//

import SwiftUI
import Photos
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsManager
    
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showSaveAlert: Bool = false
    @State private var customFileName: String = ""

    @StateObject
    private var photoLibrary = PhotoLibraryManager()

    private let spacing: CGFloat = 5
    
    @State var searchedText: String = ""

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
    }

    var body: some View {
        NavigationStack {
                HStack(spacing: 12) {
                    Text(AppInfo.appName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#000D5F"))
                    
                    Spacer()
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "bell")
                            .foregroundStyle(Color(hex: "#1A1A2E"))
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "#F5F5F7"))
                            .clipShape(.circle)
                    }
                    
                    Button {
                        
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
                
                HStack(spacing: 16) {
                    if !searchedText.isEmpty {
                        Button {
                                searchedText = ""
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

                    TextField("Search your photos...", text: $searchedText)
                        .font(.system(size: 18))
                        .textFieldStyle(.plain)

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
                                        //                                    self.showSaveAlert = true
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
            .onAppear {
                settings.requestPhotosPermission()
            }
            .background(Color(hex: "#FAFAFA"))
            .onChange(of: settings.hasPhotosAccess, initial: true) { _, hasAccess in
                if hasAccess {
                    photoLibrary.fetchPhotos()
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
    //                        showMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Search action
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
            }
        }
    }
}

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
