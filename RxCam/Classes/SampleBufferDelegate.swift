//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import UIKit
import AVFoundation
import RxSwift
import RxCocoa
import RxSwiftExt

public final class SampleBufferDelegateProxy
    : DelegateProxy<AVCaptureVideoDataOutput, AVCaptureVideoDataOutputSampleBufferDelegate>
    , DelegateProxyType
    , AVCaptureVideoDataOutputSampleBufferDelegate {

    public static let bufferQueue = DispatchQueue(label: "com.mattadatta.RxCam.SampleBufferDelegate.bufferQueue", qos: .utility)

    public static func registerKnownImplementations() {
        self.register(make: { SampleBufferDelegateProxy(parentObject: $0) })
    }

    public static func currentDelegate(for object: AVCaptureVideoDataOutput) -> AVCaptureVideoDataOutputSampleBufferDelegate? {
        return object.sampleBufferDelegate
    }

    public static func setCurrentDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate?, to object: AVCaptureVideoDataOutput) {
        if let delegate = delegate {
            object.setSampleBufferDelegate(delegate, queue: self.bufferQueue)
        } else {
            object.setSampleBufferDelegate(nil, queue: nil)
        }
    }

    public init(parentObject: ParentObject) {
        super.init(parentObject: parentObject, delegateProxy: SampleBufferDelegateProxy.self)
    }

    private var forwardToDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        return self.forwardToDelegate()
    }

    private let _didOutputSampleBuffer = PublishSubject<CMSampleBuffer>()
    public var didOutputSampleBuffer: Observable<CMSampleBuffer> {
        return self._didOutputSampleBuffer
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self._didOutputSampleBuffer.onNext(sampleBuffer)
        self.forwardToDelegate?.captureOutput?(output, didOutput: sampleBuffer, from: connection)
    }

    private let _didDropSampleBuffer = PublishSubject<CMSampleBuffer>()
    public var didDrop: Observable<CMSampleBuffer> {
        return self._didDropSampleBuffer
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self._didDropSampleBuffer.onNext(sampleBuffer)
        self.forwardToDelegate?.captureOutput?(output, didDrop: sampleBuffer, from: connection)
    }
}

public extension Reactive where Base: AVCaptureVideoDataOutput {

    public var delegate: SampleBufferDelegateProxy {
        return SampleBufferDelegateProxy.proxy(for: self.base)
    }

    public func setDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) -> Disposable {
        return SampleBufferDelegateProxy.installForwardDelegate(delegate, retainDelegate: false, onProxyForObject: self.base)
    }
}
