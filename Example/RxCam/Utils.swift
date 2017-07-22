//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import UIKit

extension UIView {

    func constrainView(_ view: UIView, insets: UIEdgeInsets = .zero) {
        view.leftAnchor.constraint(equalTo: self.leftAnchor, constant: insets.left).isActive = true
        view.rightAnchor.constraint(equalTo: self.rightAnchor, constant: insets.right).isActive = true
        view.topAnchor.constraint(equalTo: self.topAnchor, constant: insets.top).isActive = true
        view.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: insets.bottom).isActive = true
    }

    func addAndConstrainView(_ view: UIView, insets: UIEdgeInsets = .zero) {
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        self.constrainView(view, insets: insets)
    }
}

extension UIViewController {

    func addAndConstrain(_ viewController: UIViewController, insets: UIEdgeInsets = .zero) {
        self.addChildViewController(viewController)
        self.view.addAndConstrainView(viewController.view, insets: insets)
        viewController.didMove(toParentViewController: self)
    }
}
