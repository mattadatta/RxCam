//
// This file is subject to the terms and conditions defined in
// file 'LICENSE.txt', which is part of this source code package.
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
            label: "com.mattadatta.RxCam.Schedulers.sessionQueue",
            qos: .background,
            attributes: [.concurrent],
            target: nil))

    static let main = MainScheduler.instance

    private init() { }
}

extension ObservableType {

    func workSession() -> Observable<E> {
        return self.subscribeOn(Schedulers.session).observeOn(Schedulers.main)
    }
}
