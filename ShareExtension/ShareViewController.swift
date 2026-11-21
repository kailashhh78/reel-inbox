import SwiftUI
import UIKit

/// Principal class of the Share Extension (see NSExtensionPrincipalClass in
/// Config/ShareExtension-Info.plist). Hosts a SwiftUI form.
final class ShareViewController: UIViewController {
    private var model: ShareViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let model = ShareViewModel(extensionContext: extensionContext)
        self.model = model

        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        model.load()
    }
}
