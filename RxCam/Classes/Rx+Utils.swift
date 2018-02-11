//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

extension ObservableType {

    func map<T>(to: T) -> Observable<T> {
        return self.map({ _ in to })
    }
}

extension ObservableType {

    func ping() -> Observable<Void> {
        return self.map(to: ())
    }
}

extension ObservableType {

    func prevAndNext() -> Observable<(E?, E)> {
        let source = self
        return Observable.deferred {
            var prev: E? = nil
            return source.map({ next in defer { prev = next }; return (prev, next) })
        }
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
