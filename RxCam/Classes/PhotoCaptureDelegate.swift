//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import AVFoundation
import RxSwift
import RxCocoa
import RxSwiftExt

public class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    public struct Process {

        public var output: AVCapturePhotoOutput
        public var settings: AVCaptureResolvedPhotoSettings
        public var stage: Stage

        init(output: AVCapturePhotoOutput, settings: AVCaptureResolvedPhotoSettings, stage: Stage) {
            self.output = output
            self.settings = settings
            self.stage = stage
        }
    }

    public enum Stage {

        case willBeginCapture
        case willCapturePhoto
        case didCapturePhoto
        case didFinishCapture(DidFinishCapture)

        case didFinishRecordingLivePhoto(DidFinishRecordingLivePhoto)
        case didFinishProcessingLivePhoto(DidFinishProcessingLivePhoto)

        case didFinishProcessingPhoto(DidFinishProcessingPhoto)
        case didFinishProcessingRawPhoto(DidFinishProcessingPhoto)
        case didFinishProcessingData(DidFinishProcessingData)
    }

    public struct DidFinishCapture {

        public var error: Swift.Error?

        init(error: Swift.Error?) {
            self.error = error
        }
    }

    public struct DidFinishRecordingLivePhoto {

        public var eventualFileAtURL: URL

        init(eventualFileAtURL: URL) {
            self.eventualFileAtURL = eventualFileAtURL
        }
    }

    public struct DidFinishProcessingLivePhoto {

        public var outputFileURL: URL
        public var duration: CMTime
        public var photoDisplayTime: CMTime
        public var error: Swift.Error?

        init(outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, error: Swift.Error?) {
            self.outputFileURL = outputFileURL
            self.duration = duration
            self.photoDisplayTime = photoDisplayTime
            self.error = error
        }
    }

    public struct DidFinishProcessingPhoto {

        public var sampleBuffer: CMSampleBuffer?
        public var previewSampleBuffer: CMSampleBuffer?
        public var bracketSettings: AVCaptureBracketedStillImageSettings?
        public var error: Swift.Error?

        init(sampleBuffer: CMSampleBuffer?, previewSampleBuffer: CMSampleBuffer?, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
            self.sampleBuffer = sampleBuffer
            self.previewSampleBuffer = previewSampleBuffer
            self.bracketSettings = bracketSettings
            self.error = error
        }
    }

    public struct DidFinishProcessingData {

        public var data: Data?
        public var error: Swift.Error?

        init(data: Data?, error: Swift.Error?) {
            self.data = data
            self.error = error
        }
    }

    public enum Error: Swift.Error {

        case missingSampleBuffer
        case dataRepresentationFailed
    }

    let _process = ReplaySubject<Process>.createUnbounded()

    public var process: Observable<Process> {
        return self._process
    }

    override init() {
        super.init()
    }

    public func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        let process = Process(output: captureOutput, settings: resolvedSettings, stage: .willBeginCapture)
        self._process.onNext(process)
    }

    public func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .willCapturePhoto)
        self._process.onNext(process)
    }

    public func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .didCapturePhoto)
        self._process.onNext(process)
    }

    public func capture(_ captureOutput: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        let didFinishRecordingLivePhoto = DidFinishRecordingLivePhoto(eventualFileAtURL: outputFileURL)
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .didFinishRecordingLivePhoto(didFinishRecordingLivePhoto))
        self._process.onNext(process)
    }

    public func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplay photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Swift.Error?) {
        let didFinishProcessingLivePhoto = DidFinishProcessingLivePhoto(
            outputFileURL: outputFileURL,
            duration: duration,
            photoDisplayTime: photoDisplayTime,
            error: error)
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .didFinishProcessingLivePhoto(didFinishProcessingLivePhoto))
        self._process.onNext(process)
    }

    public func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Swift.Error?) {
        let didFinishCapture = DidFinishCapture(error: error)
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .didFinishCapture(didFinishCapture))
        self._process.onNext(process)
        self._process.onCompleted()
    }
}

public extension PhotoCaptureDelegate {

    public static func createDelegate() -> PhotoCaptureDelegate {
        return PhotoCaptureDelagate10()
    }
}

final class PhotoCaptureDelagate10: PhotoCaptureDelegate {

    override init() {
        super.init()
    }

    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        let didFinishProcessingPhoto = DidFinishProcessingPhoto(
            sampleBuffer: photoSampleBuffer,
            previewSampleBuffer: previewPhotoSampleBuffer,
            bracketSettings: bracketSettings,
            error: error)
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .didFinishProcessingPhoto(didFinishProcessingPhoto))
        self._process.onNext(process)
    }

    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingRawPhotoSampleBuffer rawSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        let didFinishProcessingPhoto = DidFinishProcessingPhoto(
            sampleBuffer: rawSampleBuffer,
            previewSampleBuffer: previewPhotoSampleBuffer,
            bracketSettings: bracketSettings,
            error: error)
        let process = Process(
            output: captureOutput,
            settings: resolvedSettings,
            stage: .didFinishProcessingRawPhoto(didFinishProcessingPhoto))
        self._process.onNext(process)
    }
}

//@available(iOS 11.0, *)
//final class PhotoCaptureDelagate11: PhotoCaptureDelegate {
//
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//
//    }
//}

private extension PhotoCaptureDelegate.Stage {

    typealias ConvertToData = (CMSampleBuffer, CMSampleBuffer?) -> Data?

    var didFinishProcessingPhoto: (PhotoCaptureDelegate.DidFinishProcessingPhoto, ConvertToData)? {
        switch self {
        case .didFinishProcessingPhoto(let didFinishProcessingPhoto):
            return (didFinishProcessingPhoto, AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:previewPhotoSampleBuffer:))
        case .didFinishProcessingRawPhoto(let didFinishProcessingPhoto):
            return (didFinishProcessingPhoto, AVCapturePhotoOutput.dngPhotoDataRepresentation(forRawSampleBuffer:previewPhotoSampleBuffer:))
        default:
            return nil
        }
    }
}

private extension PhotoCaptureDelegate.Process {

    init(other: PhotoCaptureDelegate.Process, didFinishProcessingData: PhotoCaptureDelegate.DidFinishProcessingData) {
        self.output = other.output
        self.settings = other.settings
        self.stage = .didFinishProcessingData(didFinishProcessingData)
    }
}

public extension ObservableType where E == PhotoCaptureDelegate.Process {

    func toDataRepresentation() -> Observable<PhotoCaptureDelegate.Process> {
        return self
            .observeOn(Schedulers.background)
            .filterMap { process in
                guard let (info, convertToData) = process.stage.didFinishProcessingPhoto else {
                    return .map(process)
                }

                if let error = info.error {
                    let process = PhotoCaptureDelegate.Process(
                        other: process,
                        didFinishProcessingData: PhotoCaptureDelegate.DidFinishProcessingData(
                            data: nil,
                            error: error))
                    return .map(process)
                }

                guard let sampleBuffer = info.sampleBuffer else {
                    let process = PhotoCaptureDelegate.Process(
                        other: process,
                        didFinishProcessingData: PhotoCaptureDelegate.DidFinishProcessingData(
                            data: nil,
                            error: PhotoCaptureDelegate.Error.missingSampleBuffer))
                    return .map(process)
                }

                guard let data = convertToData(sampleBuffer, info.previewSampleBuffer) else {
                    let process = PhotoCaptureDelegate.Process(
                        other: process,
                        didFinishProcessingData: PhotoCaptureDelegate.DidFinishProcessingData(
                            data: nil,
                            error: PhotoCaptureDelegate.Error.dataRepresentationFailed))
                    return .map(process)
                }

                let process = PhotoCaptureDelegate.Process(
                    other: process,
                    didFinishProcessingData: PhotoCaptureDelegate.DidFinishProcessingData(
                        data: data,
                        error: nil))
                return .map(process)
            }
            .observeOn(Schedulers.main)
    }
}

public extension Reactive where Base: AVCapturePhotoOutput {

    public func takePicture(with settings: AVCapturePhotoSettings) -> Observable<PhotoCaptureDelegate.Process> {
        let output = self.base
        let delegate = PhotoCaptureDelegate.createDelegate()
        var ref: AVCapturePhotoCaptureDelegate? = delegate
        output.capturePhoto(with: settings, delegate: delegate)
        return delegate
            .process
            .do(onCompleted: {
                _ = ref
                ref = nil
            })
    }
}
