//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import MapKit
import AVFoundation
import RxSwift
import RxCocoa
import RxSwiftExt
import RxGesture

public final class RxCamera {

    public let session = AVCaptureSession()

    // Externally configurable
    private let configure      = PublishSubject<ConfigOptions>()
    private let cameraSettings = PublishSubject<CameraSettings>()
    private let focusSettings  = PublishSubject<FocusSettings>()
    private let isActive       = Variable<Bool>(false)

    // Internally managed
    private let disposeBag = DisposeBag()

    // Externally visible
    public let isRunning: Observable<Bool>
    public let configResult: Observable<Result<Config>>
    public let status: Observable<Status>
    public let subjectAreaDidChange: Observable<Void>

    public init() {
        let session = self.session
        let nc = NotificationCenter.default

        let configOptions = self.configure.asObservable()
        let cameraSettings = self.cameraSettings.asObservable()
        let focusSettings = self.focusSettings.asObservable()
        let isActive = self.isActive.asObservable()

        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera10_2],
            mediaType: .video,
            position: .unspecified)

        let availableDevices = deviceDiscoverySession
            .rx.observe([AVCaptureDevice].self, "devices", options: [.initial, .new])
            .unwrap()
            .shareReplayLatestWhileConnected()

        let videoDeviceInputResult = Observable
            .combineLatest(configOptions, cameraSettings)
            .flatMapLatest { options, settings in
                return RxCameraUtils.videoDeviceInput(from: availableDevices, with: settings)
                    .asObservable()
                    .asResult()
            }
            .prevAndNext()
            .flatMapLatest { prevEvent, nextEvent in
                return session.rx.removeInput(prevEvent?.element, andAttachInput: nextEvent.element)
                    .asObservable()
                    .asResult()
            }
            .shareReplayLatestWhileConnected()

        let audioDeviceInputResult = configOptions
            .flatMapLatest { options -> Observable<Result<AVCaptureDeviceInput?>> in
                guard options.includeAudio else {
                    return .just(Result<AVCaptureDeviceInput?>.element(nil))
                }
                return RxCameraUtils.audioDeviceInput()
                    .asObservable()
                    .map(Optional.init)
                    .asResult()
            }
            .prevAndNext()
            .flatMapLatest { prevEvent, nextEvent -> Observable<Result<AVCaptureDeviceInput?>> in
                return session.rx.removeInput((prevEvent?.element ?? nil), andAttachInput: (nextEvent.element ?? nil))
                    .asObservable()
                    .asResult()
            }
            .shareReplayLatestWhileConnected()

        let photoOutputResult = configOptions
            .flatMapLatest { options in
                return RxCameraUtils.photoOutput()
                    .asObservable()
                    .asResult()
            }
            .prevAndNext()
            .flatMapLatest { prevEvent, nextEvent in
                return session.rx.removeOutput(prevEvent?.element, andAttachOutput: nextEvent.element)
                    .asObservable()
                    .asResult()
            }
            .shareReplayLatestWhileConnected()

        let config = Observable.combineLatest(
            videoDeviceInputResult.resultingElements(),
            audioDeviceInputResult.resultingElements(),
            photoOutputResult.resultingElements(),
            resultSelector: {
                Config(
                    videoDeviceInput: $0,
                    audioDeviceInput: $1,
                    photoOutput: $2)
            })
            .shareReplayLatestWhileConnected()

        let configErrors = Observable
            .of(
                videoDeviceInputResult.resultingErrors(),
                audioDeviceInputResult.resultingErrors(),
                photoOutputResult.resultingErrors())
            .merge()
            .map({ Result<Config>.error($0) })

        self.configResult = Observable
            .of(
                config.map({ Result<Config>.element($0) }),
                configErrors)
            .merge()
            .shareReplayLatestWhileConnected()

        let lastReportedRunning = BehaviorSubject<Bool>(value: false)

        Observable
            .combineLatest(config, isActive, resultSelector: { $1 })
            .filter({ $0 != session.isRunning })
            .distinctUntilChanged()
            .observeOn(Schedulers.session)
            .map { shouldRun in
                if shouldRun {
                    session.startRunning()
                } else {
                    session.stopRunning()
                }
                return session.isRunning
            }
            .observeOn(Schedulers.main)
            .bind(to: lastReportedRunning)
            .disposed(by: self.disposeBag)

        self.isRunning = Observable
            .combineLatest(config, isActive)
            .flatMapLatest { config, isActive -> Observable<Bool> in
                guard isActive else { return .empty() }
                return session
                    .rx.observe(Bool.self, "running", options: [.initial, .new])
                    .unwrap()
            }
            .shareReplayLatestWhileConnected()

        let sessionRuntimeError = Observable
            .combineLatest(config, isActive)
            .flatMapLatest { config, isActive -> Observable<AVError> in
                guard isActive else { return .empty() }
                return nc
                    .rx.notification(.AVCaptureSessionRuntimeError, object: session)
                    .map({ $0.userInfo?[AVCaptureSessionErrorKey] as? NSError }).unwrap()
                    .map({ AVError(_nsError: $0) })
            }
            .shareReplayLatestWhileConnected()

        let mediaServicesResetError = sessionRuntimeError
            .map({ $0.code == .mediaServicesWereReset })
            .trueOnly()

        let someSessionRuntimeError = sessionRuntimeError
            .map({ $0.code != .mediaServicesWereReset })
            .trueOnly()

        let mediaServicesResetIsRunning = mediaServicesResetError
            .withLatestFrom(lastReportedRunning)
            .shareReplayLatestWhileConnected()

        mediaServicesResetIsRunning
            .trueOnly().ping()
            .observeOn(Schedulers.session)
            .map {
                session.startRunning()
                return session.isRunning
            }
            .observeOn(Schedulers.main)
            .bind(to: lastReportedRunning)
            .disposed(by: self.disposeBag)

        let badMediaServicesResetError = mediaServicesResetIsRunning
            .falseOnly().not()

        let sessionWasInterrupted = Observable
            .combineLatest(config, isActive)
            .flatMapLatest { config, isActive -> Observable<AVCaptureSession.InterruptionReason> in
                guard isActive else { return .empty() }
                return nc
                    .rx.notification(.AVCaptureSessionWasInterrupted, object: session)
                    .map { notification -> AVCaptureSession.InterruptionReason? in
                        guard
                            let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
                            let reasonIntegerValue = reasonValue.integerValue,
                            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) else
                        {
                            return nil
                        }
                        return reason
                    }
                    .unwrap()
            }
            .shareReplayLatestWhileConnected()

        let sessionInUseByAnotherClient = sessionWasInterrupted
            .map({ $0 == .audioDeviceInUseByAnotherClient || $0 == .videoDeviceInUseByAnotherClient })
            .trueOnly()

        let sessionCurrentlyUnavailable = sessionWasInterrupted
            .map({ $0 == .videoDeviceNotAvailableWithMultipleForegroundApps })
            .trueOnly()

        let statusNeedsManualResume = Observable
            .of(someSessionRuntimeError, badMediaServicesResetError, sessionInUseByAnotherClient)
            .merge()
            .mapTo(Status.requiresManualResume)

        let statusUnavailable = Observable
            .of(sessionCurrentlyUnavailable)
            .switchLatest()
            .mapTo(Status.unavailable)

        let sessionInterruptionEnded = Observable
            .combineLatest(config, isActive)
            .flatMapLatest { config, isActive -> Observable<Notification> in
                guard isActive else { return .empty() }
                return nc.rx.notification(.AVCaptureSessionInterruptionEnded, object: session)
        }

        let statusAvailable = sessionInterruptionEnded
            .mapTo(Status.available)

        self.status = Observable
            .of(statusNeedsManualResume, statusUnavailable, statusAvailable)
            .merge()
            .shareReplayLatestWhileConnected()

        let subjectAreaDidChange = Observable
            .combineLatest(videoDeviceInputResult.optionalElements(), isActive)
            .flatMapLatest { input, isActive -> Observable<Void> in
                guard let input = (input ?? nil), isActive else { return .empty() }
                return nc
                    .rx.notification(.AVCaptureDeviceSubjectAreaDidChange, object: input.device)
                    .ping()
            }
            .shareReplayLatestWhileConnected()

        subjectAreaDidChange
            .map {
                return FocusSettings(
                    focusOptions: FocusOptions(focusMode: .autoFocus, location: CGPoint(x: 0.5, y: 0.5)),
                    exposureOptions: ExposureOptions(exposureMode: .continuousAutoExposure, location: CGPoint(x: 0.5, y: 0.5)),
                    monitorSubjectAreaChange: false)
            }
            .bind(to: self.focusSettings)
            .disposed(by: self.disposeBag)

        self.subjectAreaDidChange = subjectAreaDidChange

        focusSettings
            .withLatestFrom(videoDeviceInputResult.optionalElements(), resultSelector: { ($0, $1) })
            .subscribe(onNext: { settings, input in
                guard let input = (input ?? nil) else { return }
                _ = input.device.rx.focus(with: settings).subscribe()
            })
            .disposed(by: self.disposeBag)
    }

    public func configure(with options: ConfigOptions = ConfigOptions(includeAudio: true)) {
        self.configure.onNext(options)
    }

    public func start() {
        self.isActive.value = true
    }

    public func stop() {
        self.isActive.value = false
    }

    public func chooseCamera(with settings: CameraSettings) {
        self.cameraSettings.onNext(settings)
    }

    public func focus(with settings: FocusSettings) {
        self.focusSettings.onNext(settings)
    }

    public func takePicture(with settings: CapturePhotoSettings) -> Observable<PhotoCaptureDelegate.Process> {
        return Observable
            .zip(
                Observable.just(settings),
                self.configResult.map({ $0.element }))
            .observeOn(Schedulers.session)
            .flatMapLatest { settings, config -> Observable<PhotoCaptureDelegate.Process> in
                guard
                    let config = config,
                    let videoDeviceInput = config.videoDeviceInput,
                    let photoOutput = config.photoOutput
                    else { return .empty() }
                
                if let connection = photoOutput.connection(with: .video) {
                    connection.videoOrientation = settings.videoOrientation
                }

                let photoSettings = AVCapturePhotoSettings()
                photoSettings.flashMode = videoDeviceInput.device.isFlashAvailable ? settings.flashMode : .off
                photoSettings.isHighResolutionPhotoEnabled = false
                if let formatType = photoSettings.__availablePreviewPhotoPixelFormatTypes.first {
                    photoSettings.previewPhotoFormat = [
                        kCVPixelBufferPixelFormatTypeKey as String : formatType
                    ]
                }

                return photoOutput.rx.takePicture(with: photoSettings)
            }
            .observeOn(Schedulers.main)
    }
}

public extension RxCamera {

    public enum Error: Swift.Error {

        case accessNotGranted
        case noCaptureDevicesAvailable([AVCaptureDevice])
        case noDeviceAvailableForMediaType(AVMediaType)
        case unableToAddCaptureInput(AVCaptureInput)
        case unableToAddCaptureOutput(AVCaptureOutput)
    }

    public struct Config {

        public var videoDeviceInput: AVCaptureDeviceInput?
        public var audioDeviceInput: AVCaptureDeviceInput?
        public var photoOutput: AVCapturePhotoOutput?

        public init(videoDeviceInput: AVCaptureDeviceInput?, audioDeviceInput: AVCaptureDeviceInput?, photoOutput: AVCapturePhotoOutput?) {
            self.videoDeviceInput = videoDeviceInput
            self.audioDeviceInput = audioDeviceInput
            self.photoOutput = photoOutput
        }
    }

    public struct ConfigOptions {

        public var includeAudio: Bool

        public init(includeAudio: Bool) {
            self.includeAudio = includeAudio
        }
    }

    public struct FocusOptions {

        public var focusMode: AVCaptureDevice.FocusMode
        public var location: CGPoint

        public init(focusMode: AVCaptureDevice.FocusMode, location: CGPoint) {
            self.focusMode = focusMode
            self.location = location

        }
    }

    public struct ExposureOptions {

        public var exposureMode: AVCaptureDevice.ExposureMode
        public var location: CGPoint

        public init(exposureMode: AVCaptureDevice.ExposureMode, location: CGPoint) {
            self.exposureMode = exposureMode
            self.location = location
        }
    }

    public struct FocusSettings {

        public var focusOptions: FocusOptions?
        public var exposureOptions: ExposureOptions?
        public var monitorSubjectAreaChange: Bool?

        public init(focusOptions: FocusOptions? = nil, exposureOptions: ExposureOptions? = nil, monitorSubjectAreaChange: Bool? = nil) {
            self.focusOptions = focusOptions
            self.exposureOptions = exposureOptions
            self.monitorSubjectAreaChange = monitorSubjectAreaChange
        }
    }

    public struct CameraSettings {

        public var deviceType: AVCaptureDevice.DeviceType
        public var devicePosition: AVCaptureDevice.Position

        public init(deviceType: AVCaptureDevice.DeviceType, devicePosition: AVCaptureDevice.Position) {
            self.deviceType = deviceType
            self.devicePosition = devicePosition
        }
    }

    public struct CapturePhotoSettings {

        public var videoOrientation: AVCaptureVideoOrientation
        public var flashMode: AVCaptureDevice.FlashMode

        public init(videoOrientation: AVCaptureVideoOrientation, flashMode: AVCaptureDevice.FlashMode) {
            self.videoOrientation = videoOrientation
            self.flashMode = flashMode
        }
    }

    public enum Status {

        case available
        case unavailable
        case requiresManualResume
    }
}

public extension Reactive where Base: AVCaptureSession {

    public func removeInput <Input: AVCaptureInput> (_ prevInput: Input?, andAttachInput nextInput: Input?) -> Single<Input?> {
        let session = self.base
        return Single.create { single in
            session.beginConfiguration(); defer { session.commitConfiguration() }

            let disposable = Disposables.create()

            if let prevInput = prevInput {
                session.removeInput(prevInput)
            }

            if let nextInput = nextInput {
                if session.canAddInput(nextInput) {
                    session.addInput(nextInput)
                } else {
                    single(.error(RxCamera.Error.unableToAddCaptureInput(nextInput)))
                    return disposable
                }
            }

            single(.success(nextInput))

            return disposable
        }.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }

    public func removeOutput <Output: AVCaptureOutput> (_ prevOutput: Output?, andAttachOutput nextOutput: Output?) -> Single<Output?> {
        let session = self.base
        return Single.create { single in
            session.beginConfiguration(); defer { session.commitConfiguration() }

            let disposable = Disposables.create()

            if let prevOutput = prevOutput {
                session.removeOutput(prevOutput)
            }

            if let nextOutput = nextOutput {
                if session.canAddOutput(nextOutput) {
                    session.addOutput(nextOutput)
                } else {
                    single(.error(RxCamera.Error.unableToAddCaptureOutput(nextOutput)))
                    return disposable
                }
            }

            single(.success(nextOutput))

            return disposable
        }.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }
}

public extension Reactive where Base: AVCaptureDevice {

    public func focus(with settings: RxCamera.FocusSettings) -> Single<RxCamera.FocusSettings> {
        let device = self.base
        return Single.create { single in
            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }

                if let focusOptions = settings.focusOptions {
                    if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusOptions.focusMode) {
                        device.focusMode = focusOptions.focusMode
                        device.focusPointOfInterest = focusOptions.location
                    }
                }

                if let exposureOptions = settings.exposureOptions {
                    if device.isFocusPointOfInterestSupported && device.isExposureModeSupported(exposureOptions.exposureMode) {
                        device.exposureMode = exposureOptions.exposureMode
                        device.exposurePointOfInterest = exposureOptions.location
                    }
                }

                if let monitorSubjectAreaChange = settings.monitorSubjectAreaChange {
                    device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                }

                single(.success(settings))
            } catch let error {
                single(.error(error))
            }

            return Disposables.create()
        }.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }
}

private struct RxCameraUtils {

    static func videoDeviceInput(from devices: Observable<[AVCaptureDevice]>, with settings: RxCamera.CameraSettings) -> Single<AVCaptureDeviceInput> {
        return devices.take(1)
            .asSingle()
            .observeOn(Schedulers.session)
            .map { devices in
                let foundDevice =
                    devices.filter({ $0.position == settings.devicePosition && $0.deviceType == settings.deviceType }).first ??
                        devices.filter({ $0.position == settings.devicePosition }).first

                guard let videoDevice = foundDevice else { throw RxCamera.Error.noCaptureDevicesAvailable(devices) }
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                return videoDeviceInput
            }
            .observeOn(Schedulers.main)
    }

    static func audioDeviceInput() -> Single<AVCaptureDeviceInput> {
        return Single.create { single in
            let disposable = Disposables.create()
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                single(.error(RxCamera.Error.noDeviceAvailableForMediaType(.audio)))
                return disposable
            }
            do {
                let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                single(.success(audioDeviceInput))
            } catch let error {
                single(.error(error))
            }
            return disposable
        }.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }

    static func photoOutput() -> Single<AVCapturePhotoOutput> {
        return Single.create { single in
            let photoOutput = AVCapturePhotoOutput()
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = false
            single(.success(photoOutput))
            return Disposables.create()
        }.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }

    private init() { }
}

public extension Reactive where Base: AVCaptureSession {

    func addManagedOutput <Output: AVCaptureOutput> (createOutput: @escaping () -> Output) -> Observable<Output> {
        let session = self.base
        return Observable.create { observer in
            session.beginConfiguration(); defer { session.commitConfiguration() }

            let output = createOutput()
            let didAdd: Bool
            if session.canAddOutput(output) {
                session.addOutput(output)
                didAdd = true
                observer.onNext(output)
            } else {
                didAdd = false
                observer.onError(RxCamera.Error.unableToAddCaptureOutput(output))
            }

            return Disposables.create {
                guard didAdd else { return }
                session.beginConfiguration(); defer { session.commitConfiguration() }
                session.removeOutput(output)
            }
        }.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }

    func addManagedOutput <Output: AVCaptureOutput> (output: Output) -> Observable<Output> {
        return self.addManagedOutput(createOutput: { output })
    }
}
