//
//  ContentView.swift
//  CameraVisionLite
//
//  Created by Andrey Aleksandrov on 09/05/2024.
//

import SwiftUI
import CoreML
import Vision
import AVKit

extension CIImage {
    func toImage() -> NSImage? {
        let context = CIContext()
        if let cgImage = context.createCGImage(self, from: self.extent) {
            return NSImage(cgImage: cgImage, size: NSSize(width: self.extent.width, height: self.extent.height))
        }
        return nil
    }
}

struct ContentView: View {
    
    @ObservedObject var videoProcessor = VideoProcessor()
    @State private var isAnimating = false
    @State private var defaultLink: String = ""
    @State private var insertLink: String = ""
    @State private var showingSettings: Bool = false
    @State private var autoSaveObjects: Bool = false
    @State private var selectedFolderURL: URL? = nil
    @State private var message: String = ""
    @State private var autoRecordingEnabled = false
    let videoSize = CGSize(width: 600, height: 400)

    var body: some View {
        VStack {
            Spacer().frame(height: 50)

            ZStack {
                HStack {
                    HStack {
                        Rectangle()
                            .frame(width: 300, height: 600, alignment: .center)
                            .cornerRadius(10)
                            .foregroundColor(.black.opacity(0.5))
                            .overlay {
                                ScrollView {
                                    VStack {
                                        ForEach(videoProcessor.observations, id: \.self) { observation in
                                            if let identifier = observation.labels.first?.identifier {
                                                Text("Object detected: \(identifier)")
                                            }
                                        }
                                    }
                                }
                            }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Rectangle()
                            .frame(width: 300, height: 600, alignment: .center)
                            .cornerRadius(10)
                            .foregroundColor(.black.opacity(0.5))
                            .overlay {
                                List {
                                    // Здесь можно добавить код для отображения записанных видеофайлов
                                }
                            }
                    }
                }.padding(.top, 50)

                Rectangle()
                    .frame(width: 800, height: 1, alignment: .center)
                    .padding(.top, 650)

                Rectangle()
                    .frame(width: 800, height: 1, alignment: .center)
                    .padding(.bottom, 550)

                Button(action: {
                    if autoRecordingEnabled {
                        autoRecordingEnabled = false
                        videoProcessor.forceStopRecording()
                        message = "Автоматическая запись видео отключена."
                    } else {
                        autoRecordingEnabled = true
                        message = "Автоматическая запись видео включена."
                    }
                }) {
                    Text(autoRecordingEnabled ? "Videorecording Objects ON" : "Videorecording Objects OFF")
                }
                .padding(.bottom, 620)
                .padding(.leading, 950)

                Button(action: { saveCurrentFrame() }) {
                    Text("Save")
                }
                .padding(.bottom, 700)
                .padding(.trailing, 1000)

                Button(action: { showingSettings.toggle() }) {
                    Text("Настройки")
                }
                .padding(.bottom, 700)
                .padding(.trailing, 1200)
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }

                ZStack {
                    Rectangle()
                        .cornerRadius(10)
                        .shadow(radius: 10)
                        .foregroundColor(.black.opacity(0.5))

                    HStack {
                        TextField("Insert link", text: $insertLink)
                            .foregroundColor(.black)
                            .background(Color.black.opacity(0.1))

                        Button("Load") {
                            videoProcessor.insertLink = insertLink
                            videoProcessor.setupVideoStream()
                        }
                    }
                    .frame(minWidth: 720, idealWidth: 720, maxWidth: .infinity, minHeight: 40, idealHeight: 40, maxHeight: 40, alignment: .center)
                }
                .frame(width: 750, height: 50, alignment: .center)
                .padding(.bottom, 700)

                if let image = videoProcessor.currentFrame?.toImage() {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 600, height: 400)
                        .padding(.bottom, 100)
                        .overlay {
                            
                            ForEach(videoProcessor.observations, id: \.self) { observation in
                                RectangleView(observation: observation, imageSize: videoSize)
                            }
                            .padding(.bottom, 100)
                            
                        }
                }
            }
        }
        .frame(minWidth: 1366, idealWidth: 1920, maxWidth: .infinity, minHeight: 768, idealHeight: 1080, maxHeight: .infinity)
        .onChange(of: videoProcessor.currentFrame) { _ in
            if autoRecordingEnabled {
                processFrame()
            }
            if autoSaveObjects {
                processFrame()
            }
        }
        .onAppear {
            videoProcessor.setupVideoStream()
        }
    }

    func saveImageToFolder(image: NSImage) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "saveLocationBookmark") else {
            print("Не удалось получить путь для сохранения")
            return
        }

        do {
            var isStale = false
            let saveURL = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, bookmarkDataIsStale: &isStale)
            let fileName = "detected_car_\(UUID().uuidString).jpg"
            let fileURL = saveURL.appendingPathComponent(fileName)

            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let data = bitmapImage.representation(using: .jpeg, properties: [:]) {
                do {
                    try data.write(to: fileURL)
                    message = "Image saved to \(fileURL.path)"
                } catch {
                    message = "Ошибка сохранения изображения: \(error)"
                }
            }
        } catch {
            print("Ошибка разрешения bookmarkData: \(error)")
        }
    }

    func processFrame() {
        if let frame = videoProcessor.currentFrame,
           let cgImage = CIContext().createCGImage(frame, from: frame.extent) {
            
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.extent.width, height: frame.extent.height))
            
            var objectDetected = false
            
            for observation in videoProcessor.observations {
                if observation.labels.contains(where: { $0.identifier == "car" }) {
                    objectDetected = true
                    if !videoProcessor.isRecording {
                        videoProcessor.startRecording()
                    }
                    break
                }
            }
            
            if !objectDetected, videoProcessor.isRecording {
                videoProcessor.scheduleStopRecording()
            }
        }
    }

    func saveCurrentFrame() {
        if let frame = videoProcessor.currentFrame,
           let cgImage = CIContext().createCGImage(frame, from: frame.extent) {
            
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.extent.width, height: frame.extent.height))
            saveImageToFolder(image: nsImage)
        }
    }

    func deleteAllSavedImages() {
        do {
            UserDefaults.standard.removeObject(forKey: "videoPaths")
            print("All saved videos deleted successfully.")
        } catch {
            print("Error deleting data: \(error)")
        }
    }
}











#Preview {
    ContentView()
}
