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

public final class SampleBufferDelegateProxy: DelegateProxy, DelegateProxyType, AVCaptureVideoDataOutputSampleBufferDelegate {

    public static let bufferQueue = DispatchQueue(label: "com.mattadatta.RxCam.SampleBufferDelegate.bufferQueue", qos: .utility)

    public static func currentDelegateFor(_ object: AnyObject) -> AnyObject? {
        let captureOutput = object as! AVCaptureVideoDataOutput
        return captureOutput.sampleBufferDelegate
    }

    public static func setCurrentDelegate(_ delegate: AnyObject?, toObject object: AnyObject) {
        let captureOutput = object as! AVCaptureVideoDataOutput
        if let delegate = delegate as? AVCaptureVideoDataOutputSampleBufferDelegate {
            captureOutput.setSampleBufferDelegate(delegate, queue: self.bufferQueue)
        } else {
            captureOutput.setSampleBufferDelegate(nil, queue: nil)
        }
    }

    private var forwardToDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        return self.forwardToDelegate() as? AVCaptureVideoDataOutputSampleBufferDelegate
    }

    private let _didOutputSampleBuffer = PublishSubject<CMSampleBuffer>()
    public var didOutputSampleBuffer: Observable<CMSampleBuffer> {
        return self._didOutputSampleBuffer
    }

    public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self._didOutputSampleBuffer.onNext(sampleBuffer)
        self.forwardToDelegate?.captureOutput?(captureOutput, didOutputSampleBuffer: sampleBuffer, from: connection)
    }

    private let _didDropSampleBuffer = PublishSubject<CMSampleBuffer>()
    public var didDrop: Observable<CMSampleBuffer> {
        return self._didDropSampleBuffer
    }

    public func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self._didDropSampleBuffer.onNext(sampleBuffer)
        self.forwardToDelegate?.captureOutput?(captureOutput, didDrop: sampleBuffer, from: connection)
    }
}

public extension Reactive where Base: AVCaptureVideoDataOutput {

    public var delegate: SampleBufferDelegateProxy {
        return SampleBufferDelegateProxy.proxyForObject(self.base)
    }

    public func setDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) -> Disposable {
        return SampleBufferDelegateProxy.installForwardDelegate(delegate, retainDelegate: false, onProxyForObject: self.base)
    }
}
