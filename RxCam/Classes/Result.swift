//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

public enum Result<Element> {

    case element(Element)
    case error(Error)

    public var element: Element? {
        switch self {
        case .element(let element):
            return element
        default:
            return nil
        }
    }

    public var error: Error? {
        switch self {
        case .error(let error):
            return error
        default:
            return nil
        }
    }

    public var isElement: Bool {
        return self.element != nil
    }

    public var isError: Bool {
        return self.error != nil
    }
}

public protocol ResultConvertible {
    associatedtype E

    var result: Result<E> { get }
}

extension Result: ResultConvertible {

    public var result: Result<Element> {
        return self
    }
}

extension ObservableType {

    func asResult() -> Observable<Result<E>> {
        return self
            .map({ .element($0) })
            .catchError({ .just(.error($0)) })
    }
}

extension ObservableType where E: ResultConvertible {

    func resultingElements() -> Observable<E.E> {
        return self
            .map({ $0.result })
            .filter({ $0.isElement })
            .map({ $0.element! })
    }

    func resultingErrors() -> Observable<Error> {
        return self
            .map({ $0.result })
            .filter({ $0.isError })
            .map({ $0.error! })
    }

    func optionalElements() -> Observable<E.E?> {
        return self.map({ $0.result.element })
    }
}
