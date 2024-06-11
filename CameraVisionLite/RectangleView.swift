//
//  RectangleView.swift
//  CameraVisionLite
//
//  Created by Andrey Aleksandrov on 09/05/2024.
//

import Foundation
import SwiftUI
import Vision



struct RectangleView: View {
    var observation: VNRecognizedObjectObservation
    var imageSize: CGSize

    var body: some View {
        let boundingBox = observation.boundingBox
        let frame = CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1 - boundingBox.minY - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        return Rectangle()
            .fill(Color.clear)
            .border(Color.green, width: 2)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
    
}




