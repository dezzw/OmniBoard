import SwiftUI
import UIKit

enum ViewTextExtractor {
    static func texts<V: View>(from view: V) -> [String] {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        return collectTexts(from: controller.view)
    }

    private static func collectTexts(from view: UIView) -> [String] {
        var result: [String] = []

        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            result.append(text)
        }

        if let button = view as? UIButton {
            for state: UIControl.State in [.normal, .selected, .highlighted] {
                if let title = button.title(for: state), !title.isEmpty {
                    result.append(title)
                }
            }
        }

        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            result.append(accessibilityLabel)
        }

        for subview in view.subviews {
            result.append(contentsOf: collectTexts(from: subview))
        }

        return result
    }
}
