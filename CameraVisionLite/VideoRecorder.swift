//
//  VideoRecorder.swift
//  CameraVisionLite
//
//  Created by Andrey Aleksandrov on 19.06.2024.
//

import AVFoundation
import SwiftUI
import Vision
import CoreImage

class VideoProcessor: NSObject, ObservableObject {
    var avPlayer: AVPlayer?
    var videoOutput: AVPlayerItemVideoOutput?

    var assetWriter: AVAssetWriter?
    var assetWriterInput: AVAssetWriterInput?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var videoOutputURL: URL?

    @Published var currentFrame: CIImage?
    @Published var observations: [VNRecognizedObjectObservation] = []
    @Published var insertLink: String = ""
    @Published var defaultLink: URL = URL(string: "https://camera.lipetsk.ru")!
    @Published var isRecording = false
    private var startSessionTime: CMTime?

    var updateFrameTimer: Timer?
    private var timer: Timer?

    init(avPlayer: AVPlayer? = nil, videoOutput: AVPlayerItemVideoOutput? = nil, currentFrame: CIImage? = nil) {
        self.avPlayer = avPlayer
        self.videoOutput = videoOutput
        self.currentFrame = currentFrame
    }

    deinit {
        updateFrameTimer?.invalidate()
    }

    func setupVideoStream() {
        let playerItem: AVPlayerItem
        if let url = URL(string: insertLink), !insertLink.isEmpty {
            playerItem = AVPlayerItem(url: url)
        } else {
            playerItem = AVPlayerItem(url: defaultLink)
        }

        self.avPlayer = AVPlayer(playerItem: playerItem)

        let outputSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        playerItem.add(videoOutput!)

        avPlayer?.play()

        updateFrameTimer?.invalidate()
        updateFrameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
    }

    func captureFrame() {
        guard let videoOutput = self.videoOutput, let currentTime = avPlayer?.currentTime() else { return }
        var actualTime = CMTime.zero

        if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: &actualTime) {
            DispatchQueue.main.async {
                self.currentFrame = CIImage(cvPixelBuffer: pixelBuffer)
                self.performVisionRequest(pixelBuffer: pixelBuffer)
                self.processPixelBuffer(pixelBuffer, time: actualTime)
            }
        }
    }

    func performVisionRequest(pixelBuffer: CVPixelBuffer) {
        guard let request = createCoreMLRequest() else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform CoreML request: \(error)")
        }
    }

    func createCoreMLRequest() -> VNCoreMLRequest? {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        do {
            let model = try VNCoreMLModel(for: yolov8s(configuration: configuration).model)
            return VNCoreMLRequest(model: model) { [weak self] request, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let results = request.results as? [VNRecognizedObjectObservation] {
                        let filteredResults = results.filter { observation in
                            observation.labels.contains { label in
                                label.identifier == "car" || label.identifier == "person"
                            }
                        }
                        self.observations = filteredResults
                    } else if let error = error {
                        print("Error during the model prediction: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error loading ML model: \(error)")
            return nil
        }
    }

    func startRecording() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "saveLocationBookmark") else {
            print("Не удалось получить путь для сохранения")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var isStale = false
                let saveURL = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, bookmarkDataIsStale: &isStale)
                self.videoOutputURL = saveURL.appendingPathComponent("detected_object_video_\(UUID().uuidString).mp4")

                guard let videoOutputURL = self.videoOutputURL else {
                    print("Invalid video output URL")
                    return
                }

                self.assetWriter = try AVAssetWriter(outputURL: videoOutputURL, fileType: .mp4)
                let outputSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1920,
                    AVVideoHeightKey: 1080
                ]
                self.assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
                self.assetWriterInput?.expectsMediaDataInRealTime = true

                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: 1920,
                    kCVPixelBufferHeightKey as String: 1080
                ]
                self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.assetWriterInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

                if let assetWriter = self.assetWriter, let assetWriterInput = self.assetWriterInput {
                    if assetWriter.canAdd(assetWriterInput) {
                        assetWriter.add(assetWriterInput)
                    } else {
                        print("Cannot add input to asset writer")
                        return
                    }

                    assetWriter.startWriting()
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.startSessionTime = nil
                        print("Recording setup complete")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Ошибка инициализации AVAssetWriter: \(error)")
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording, let assetWriter = assetWriter else { return }

        assetWriterInput?.markAsFinished()
        assetWriter.finishWriting { [weak self] in
            DispatchQueue.global(qos: .background).async {
                if let self = self, let videoOutputURL = self.videoOutputURL {
                    print("Video saved to: \(videoOutputURL.path)")
                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.assetWriter = nil
                        self.assetWriterInput = nil
                        self.pixelBufferAdaptor = nil
                        self.deleteEmptyFileIfNeeded(url: videoOutputURL)
                        print("Recording stopped")
                    }
                }
            }
        }
    }

    func scheduleStopRecording() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    func forceStopRecording() {
        timer?.invalidate()
        stopRecording()
    }

    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer, time: CMTime) {
        guard isRecording else {
            print("Skipping pixel buffer: Not recording")
            return
        }

        guard let pixelBufferAdaptor = pixelBufferAdaptor else {
            print("Skipping pixel buffer: Pixel buffer adaptor is nil")
            return
        }

        guard let assetWriterInput = assetWriterInput else {
            print("Skipping pixel buffer: Asset writer input is nil")
            return
        }

        guard assetWriterInput.isReadyForMoreMediaData else {
            print("Skipping pixel buffer: Asset writer input is not ready for more media data")
            return
        }

        if startSessionTime == nil {
            assetWriter?.startSession(atSourceTime: time)
            startSessionTime = time
            print("Recording started at time: \(time.seconds)")
        }

        if pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time) {
            print("Pixel buffer appended successfully at time: \(time.seconds)")
        } else {
            print("Failed to append pixel buffer at time: \(time.seconds)")
            if let assetWriter = assetWriter {
                switch assetWriter.status {
                case .failed:
                    if let error = assetWriter.error {
                        print("AssetWriter error: \(error)")
                    }
                case .unknown:
                    print("AssetWriter status is unknown")
                case .writing:
                    print("AssetWriter is writing")
                case .completed:
                    print("AssetWriter has completed")
                case .cancelled:
                    print("AssetWriter has been cancelled")
                @unknown default:
                    print("Unknown AssetWriter status")
                }
            }
        }
    }

    private func deleteEmptyFileIfNeeded(url: URL) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[FileAttributeKey.size] as? UInt64, fileSize == 0 {
                try FileManager.default.removeItem(at: url)
                print("Deleted empty file: \(url.path)")
            }
        } catch {
            print("Failed to delete empty file: \(error)")
        }
    }
}
