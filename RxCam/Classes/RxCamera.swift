//
// This file is subject to the terms and conditions defined in
// file 'LICENSE.txt', which is part of this source code package.
//

import Foundation
import MapKit
import AVFoundation
import RxSwift
import RxCocoa
import RxSwiftExt
import RxGesture

extension Reactive where Base: AVCaptureDevice {

    func focus(with settings: RxCamera.FocusSettings) -> Single<RxCamera.FocusSettings> {
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

extension Reactive where Base: AVCaptureSession {

    func removeInput <Input: AVCaptureInput> (_ prevInput: Input?, andAttachInput nextInput: Input?) -> Single<Input?> {
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

    func removeOutput <Output: AVCaptureOutput> (_ prevOutput: Output?, andAttachOutput nextOutput: Output?) -> Single<Output?> {
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
            guard let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) else {
                single(.error(RxCamera.Error.noDeviceAvailableForMediaType(AVMediaTypeAudio)))
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

public final class RxCamera {

    public enum Error: Swift.Error {

        case accessNotGranted
        case noCaptureDevicesAvailable([AVCaptureDevice])
        case noDeviceAvailableForMediaType(String)
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

        public var focusMode: AVCaptureFocusMode
        public var location: CGPoint

        public init(focusMode: AVCaptureFocusMode, location: CGPoint) {
            self.focusMode = focusMode
            self.location = location
            
        }
    }

    public struct ExposureOptions {

        public var exposureMode: AVCaptureExposureMode
        public var location: CGPoint

        public init(exposureMode: AVCaptureExposureMode, location: CGPoint) {
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

        public var deviceType: AVCaptureDeviceType
        public var devicePosition: AVCaptureDevicePosition

        public init(deviceType: AVCaptureDeviceType, devicePosition: AVCaptureDevicePosition) {
            self.deviceType = deviceType
            self.devicePosition = devicePosition
        }
    }

    public struct CapturePhotoSettings {

        public var orientation: AVCaptureVideoOrientation

        public init(orientation: AVCaptureVideoOrientation) {
            self.orientation = orientation
        }
    }

    public enum Status {

        case available
        case unavailable
        case requiresManualResume
    }



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

        let deviceDiscoverySession = AVCaptureDeviceDiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera10_2],
            mediaType: AVMediaTypeVideo,
            position: .unspecified)!

        let availableDevices = deviceDiscoverySession
            .rx.observe([AVCaptureDevice].self, "devices", options: [.initial, .new])
            .unwrap()
            .shareReplayLatestWhileConnected()

        let videoDeviceInputResult = Observable
            .combineLatest(configOptions, cameraSettings, resultSelector: { $0 })
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
            .share()

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
            .share()

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
            .share()

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
            .share()

        let configErrors = Observable
            .of(
                videoDeviceInputResult.resultingErrors(),
                audioDeviceInputResult.resultingErrors(),
                photoOutputResult.resultingErrors())
            .merge()
            .map({ Result<Config>.error($0) })

        let configResult = Observable
            .of(
                config.map({ Result<Config>.element($0) }),
                configErrors)
            .merge()

        let configResultSubject = ReplaySubject<Result<Config>>.create(bufferSize: 1)
        configResult
            .bind(to: configResultSubject)
            .disposed(by: self.disposeBag)
        self.configResult = configResultSubject.observeOn(MainScheduler.instance)

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

        let isRunning = Observable
            .combineLatest(config, isActive, resultSelector: { $0 })
            .flatMapLatest { config, isActive -> Observable<Bool> in
                guard isActive else { return .empty() }
                return session
                    .rx.observe(Bool.self, "running", options: [.initial, .new])
                    .unwrap()
            }
            .share()

        let isRunningSubject = ReplaySubject<Bool>.create(bufferSize: 1)
        isRunning
            .bind(to: isRunningSubject)
            .disposed(by: self.disposeBag)
        self.isRunning = isRunningSubject.observeOn(MainScheduler.instance)

        let sessionRuntimeError = Observable
            .combineLatest(config, isActive, resultSelector: { $0 })
            .flatMapLatest { config, isActive -> Observable<AVError> in
                guard isActive else { return .empty() }
                return nc
                    .rx.notification(.AVCaptureSessionRuntimeError, object: session)
                    .map({ $0.userInfo?[AVCaptureSessionErrorKey] as? NSError }).unwrap()
                    .map({ AVError(_nsError: $0) })
            }
            .share()

        let mediaServicesResetError = sessionRuntimeError
            .map({ $0.code == .mediaServicesWereReset })
            .trueOnly()

        let someSessionRuntimeError = sessionRuntimeError
            .map({ $0.code != .mediaServicesWereReset })
            .trueOnly()

        let mediaServicesResetIsRunning = mediaServicesResetError
            .withLatestFrom(lastReportedRunning)
            .share()

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
            .combineLatest(config, isActive, resultSelector: { $0 })
            .flatMapLatest { config, isActive -> Observable<AVCaptureSessionInterruptionReason> in
                guard isActive else { return .empty() }
                return nc
                    .rx.notification(.AVCaptureSessionWasInterrupted, object: session)
                    .map { notification -> AVCaptureSessionInterruptionReason? in
                        guard
                            let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
                            let reasonIntegerValue = reasonValue.integerValue,
                            let reason = AVCaptureSessionInterruptionReason(rawValue: reasonIntegerValue) else
                        {
                            return nil
                        }
                        return reason
                    }
                    .unwrap()
            }
            .share()

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
            .combineLatest(config, isActive, resultSelector: { $0 })
            .flatMapLatest { config, isActive -> Observable<Notification> in
                guard isActive else { return .empty() }
                return nc.rx.notification(.AVCaptureSessionInterruptionEnded, object: session)
        }

        let statusAvailable = sessionInterruptionEnded
            .mapTo(Status.available)

        let status = Observable
            .of(statusNeedsManualResume, statusUnavailable, statusAvailable)
            .merge()
        let statusSubject = ReplaySubject<Status>.create(bufferSize: 1)
        status
            .bind(to: statusSubject)
            .disposed(by: self.disposeBag)

        self.status = statusSubject.observeOn(MainScheduler.instance)

        let subjectAreaDidChange = Observable
            .combineLatest(videoDeviceInputResult.optionalElements(), isActive, resultSelector: { $0 })
            .flatMapLatest { input, isActive -> Observable<Void> in
                guard let input = (input ?? nil), isActive else { return .empty() }
                return nc
                    .rx.notification(.AVCaptureDeviceSubjectAreaDidChange, object: input.device)
                    .ping()
            }
            .share()

        let subjectAreaDidChangeSubject = ReplaySubject<Void>.create(bufferSize: 1)
        subjectAreaDidChange
            .bind(to: subjectAreaDidChangeSubject)
            .disposed(by: self.disposeBag)

        self.subjectAreaDidChange = subjectAreaDidChangeSubject.observeOn(MainScheduler.instance)

        subjectAreaDidChange
            .map {
                return FocusSettings(
                    focusOptions: FocusOptions(focusMode: .autoFocus, location: CGPoint(x: 0.5, y: 0.5)),
                    exposureOptions: ExposureOptions(exposureMode: .continuousAutoExposure, location: CGPoint(x: 0.5, y: 0.5)),
                    monitorSubjectAreaChange: false)
            }
            .bind(to: self.focusSettings)
            .disposed(by: self.disposeBag)

        focusSettings
            .withLatestFrom(videoDeviceInputResult.optionalElements(), resultSelector: { $0 })
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
                self.configResult.map({ $0.element?.photoOutput }),
                resultSelector: { $0 })
            .observeOn(Schedulers.session)
            .flatMapLatest { settings, output -> Observable<PhotoCaptureDelegate.Process> in
                guard let photoOutput = output else { return .empty() }
                if let connection = photoOutput.connection(withMediaType: AVMediaTypeVideo) {
                    connection.videoOrientation = settings.orientation
                }

                let photoSettings = AVCapturePhotoSettings()
                photoSettings.flashMode = .off
                photoSettings.isHighResolutionPhotoEnabled = true
                if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String : photoSettings.availablePreviewPhotoPixelFormatTypes.first!]
                }

                return photoOutput.rx.takePicture(with: photoSettings)
            }
            .observeOn(Schedulers.main)
    }
}
