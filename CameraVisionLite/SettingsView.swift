//
//  SettingsView.swift
//  CameraVisionLite
//
//  Created by Andrey Aleksandrov on 03.06.2024.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("videoResolution") private var videoResolution: String = "1080p"
    @AppStorage("frameRate") private var frameRate: Int = 30
    @State private var selectedFolderURL: URL? = nil

    var body: some View {
        Form {
            Section(header: Text("Видео Настройки")) {
                Picker("Разрешение видео", selection: $videoResolution) {
                    Text("720p").tag("720p")
                    Text("1080p").tag("1080p")
                    Text("4K").tag("4K")
                }
                Stepper("Частота кадров: \(frameRate) fps", value: $frameRate, in: 1...60)
            }

            Section(header: Text("Сохранение")) {
                Text("Папка для сохранения: \(selectedFolderURL?.path ?? "Не выбрано")")
                Button("Выбрать папку") {
                    selectFolder { url in
                        if let url = url {
                            selectedFolderURL = url
                        }
                    }
                }
            }

            Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .navigationTitle("Настройки")
        .onAppear {
            if let bookmarkData = UserDefaults.standard.data(forKey: "saveLocationBookmark") {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, bookmarkDataIsStale: &isStale)
                    selectedFolderURL = url
                } catch {
                    print("Ошибка разрешения bookmarkData: \(error)")
                }
            }
        }
    }
    
    
    
    
    
    func selectFolder(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let bookmarkData = try url.bookmarkData()
                    UserDefaults.standard.set(bookmarkData, forKey: "saveLocationBookmark")
                    completion(url)
                } catch {
                    print("Ошибка создания bookmarkData: \(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }

    
    
    
    
    
}

