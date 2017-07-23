//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

struct Schedulers {

    static let session = SerialDispatchQueueScheduler(
        internalSerialQueueName: "com.mattadatta.RxCam.Schedulers.sessionQueue")

    static let background = ConcurrentDispatchQueueScheduler(
        queue: DispatchQueue(
            label: "com.mattadatta.RxCam.Schedulers.backgroundQueue",
            qos: .background,
            attributes: [.concurrent],
            target: nil))

    static let main = MainScheduler.instance

    private init() { }
}
