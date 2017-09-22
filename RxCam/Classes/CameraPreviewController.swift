//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import AVFoundation
import RxSwift
import RxCocoa
import RxSwiftExt
import RxGesture

public final class CameraPreviewController: UIViewController {

    public let camera = RxCamera()
    private let disposeBag = DisposeBag()

    private var previewView: PreviewView {
        return self.view as! PreviewView
    }

    public var previewLayer: AVCaptureVideoPreviewLayer {
        return self.previewView.videoPreviewLayer
    }

    public override func loadView() {
        self.view = PreviewView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.previewView.session = self.camera.session
        self.previewView.videoPreviewLayer.videoGravity = .resizeAspectFill

        self.previewView
            .rx.tapGesture().when(.recognized)
            .asLocation()
            .subscribe(onNext: { [unowned self] location in
                self.focus(withViewLocation: location)
            })
            .disposed(by: self.disposeBag)

        self.camera
            .configResult
            .resultingElements().ping()
            .subscribe(onNext: { [unowned self] in
                self.previewView.videoPreviewLayer.connection?.videoOrientation = UIScreen.main.orientation.videoOrientation ?? .portrait
            })
            .disposed(by: self.disposeBag)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.camera.start()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.camera.stop()
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let connection = self.previewView.videoPreviewLayer.connection else { return }
        coordinator.animate(alongsideTransition: { _ in
            if let orientation = UIScreen.main.orientation.videoOrientation {
                connection.videoOrientation = orientation
            }
        })
    }

    public func takePicture(flashMode: AVCaptureDevice.FlashMode = .off) -> Observable<PhotoCaptureDelegate.Process> {
        guard let connection = self.previewView.videoPreviewLayer.connection else { return .empty() }
        return self.camera.takePicture(
            with: RxCamera.CapturePhotoSettings(
                orientation: connection.videoOrientation,
                flashMode: flashMode))
    }

    public func focus(withViewLocation location: CGPoint) {
        let devicePoint = self.previewView.videoPreviewLayer
            .captureDevicePointConverted(
                fromLayerPoint: location)

        let focusSettings = RxCamera.FocusSettings(
            focusOptions: RxCamera.FocusOptions(
                focusMode: .autoFocus,
                location: devicePoint),
            exposureOptions: RxCamera.ExposureOptions(
                exposureMode: .autoExpose,
                location: devicePoint),
            monitorSubjectAreaChange: true)

        self.camera.focus(with: focusSettings)
    }

    public func cropImageToPreviewBounds(_ image: UIImage) -> UIImage {
        let previewLayer = self.previewLayer
        let outputRect = previewLayer.metadataOutputRectConverted(fromLayerRect: previewLayer.bounds)
        let cgImage = image.cgImage!
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: outputRect.origin.x * width,
            y: outputRect.origin.y * height,
            width: outputRect.size.width * width,
            height: outputRect.size.height * height)

        let croppedImage = UIImage(
            cgImage: cgImage.cropping(to: cropRect)!,
            scale: 1,
            orientation: image.imageOrientation)

        return croppedImage
    }
}

private final class PreviewView: UIView {

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return self.layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { return self.videoPreviewLayer.session }
        set { self.videoPreviewLayer.session = newValue }
    }
}
