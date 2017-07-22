//
//  ViewController.swift
//  RxCam
//
//  Created by Matthew Brown on 07/18/2017.
//  Copyright (c) 2017 Matthew Brown. All rights reserved.
//

import UIKit
import RxCam

final class ViewController: UIViewController {

    private let cameraPreviewController = CameraPreviewController()

    private var camera: RxCamera {
        return self.cameraPreviewController.camera
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let camera = self.camera
        let cameraPreviewController = self.cameraPreviewController

        camera.configure(with: RxCamera.ConfigOptions(includeAudio: false))
        camera.chooseCamera(with: RxCamera.CameraSettings(deviceType: .builtInDualCamera10_2, devicePosition: .back))
        self.addAndConstrain(cameraPreviewController)
    }
}
