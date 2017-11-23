//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

extension ObservableType {

    func ping() -> Observable<Void> {
        return self.map(to: ())
    }
}

extension ObservableType {

    func prevAndNext() -> Observable<(E?, E)> {
        return self
            .scan((.none, .none), accumulator: { ($0.1, $1) })
            .map({ ($0, $1!) })
    }
}

extension ObservableType where E == Bool {

    func trueOnly() -> Observable<Bool> {
        return self.ignore(false)
    }

    func falseOnly() -> Observable<Bool> {
        return self.ignore(true)
    }
}
