//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa
import RxSwiftExt

// Courtesy of: http://stackoverflow.com/a/37329460
// Allows us to reliably get the screen orientation in an application or application extension.
extension UIScreen {

    var orientation: UIInterfaceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: self.fixedCoordinateSpace)
        if point == .zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeRight
        } else {
            return .unknown
        }
    }
}

extension UIInterfaceOrientation {

    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return nil
        }
    }
}

public extension AVCaptureDeviceType {

    public static var builtInDualCamera10_2: AVCaptureDeviceType {
        if #available(iOS 10.2, *) {
            return .builtInDualCamera
        } else {
            return .builtInDuoCamera
        }
    }
}
