//
//  ModelContainer.swift
//  CameraVisionLite
//
//  Created by Andrey Aleksandrov on 14/05/2024.
//

import Foundation
import SwiftData



@Model
class DetectedObject: Identifiable {
    @Attribute(.unique) var id: UUID
    @Attribute var videoData: Data
    @Attribute var date: Date
    
    init(id: UUID = UUID(), videoData: Data, date: Date = Date()) {
        self.id = id
        self.videoData = videoData
        self.date = date
    }
}
