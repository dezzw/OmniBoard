import SwiftUI
import UIKit

enum ViewTextExtractor {
    static func texts<V: View>(from view: V) -> [String] {
        if Thread.isMainThread {
            return extractTexts(from: view)
        }

        var result: [String] = []
        DispatchQueue.main.sync {
            result = extractTexts(from: view)
        }
        return result
    }

    private static func extractTexts<V: View>(from view: V) -> [String] {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 2_000))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        controller.view.frame = window.bounds
        _ = controller.sizeThatFits(in: window.bounds.size)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        layoutScrollViews(in: controller.view)

        UIGraphicsBeginImageContext(window.bounds.size)
        controller.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        UIGraphicsEndImageContext()

        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        layoutScrollViews(in: controller.view)

        return collectTexts(from: controller.view)
    }

    private static func layoutScrollViews(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.layoutIfNeeded()
            let offsets: [CGFloat] = [0, scrollView.contentSize.height / 2, max(0, scrollView.contentSize.height - scrollView.bounds.height)]
            for offset in offsets {
                scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                scrollView.layoutIfNeeded()
            }
        }

        for subview in view.subviews {
            layoutScrollViews(in: subview)
        }
    }

    private static func collectTexts(from view: UIView) -> [String] {
        var result: [String] = []

        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            result.append(text)
        }

        if let textView = view as? UITextView, !textView.text.isEmpty {
            result.append(textView.text)
        }

        if let button = view as? UIButton {
            for state: UIControl.State in [.normal, .selected, .highlighted, .disabled] {
                if let title = button.title(for: state), !title.isEmpty {
                    result.append(title)
                }
            }
        }

        if let label = view.accessibilityLabel, !label.isEmpty {
            result.append(label)
        }

        if let value = view.accessibilityValue, !value.isEmpty {
            result.append(value)
        }

        if let elements = view.accessibilityElements {
            for element in elements {
                result.append(contentsOf: collectTexts(from: element))
            }
        }

        if let tableView = view as? UITableView {
            tableView.layoutIfNeeded()
            for section in 0..<tableView.numberOfSections {
                for row in 0..<tableView.numberOfRows(inSection: section) {
                    tableView.scrollToRow(at: IndexPath(row: row, section: section), at: .middle, animated: false)
                    tableView.layoutIfNeeded()
                    if let cell = tableView.cellForRow(at: IndexPath(row: row, section: section)) {
                        result.append(contentsOf: collectTexts(from: cell.contentView))
                    }
                }
            }
        }

        if let collectionView = view as? UICollectionView {
            collectionView.layoutIfNeeded()
            for section in 0..<collectionView.numberOfSections {
                for item in 0..<collectionView.numberOfItems(inSection: section) {
                    let indexPath = IndexPath(item: item, section: section)
                    collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                    collectionView.layoutIfNeeded()
                    if let cell = collectionView.cellForItem(at: indexPath) {
                        result.append(contentsOf: collectTexts(from: cell.contentView))
                    }
                }
            }
        }

        for subview in view.subviews {
            result.append(contentsOf: collectTexts(from: subview))
        }

        return result
    }

    private static func collectTexts(from element: Any) -> [String] {
        if let view = element as? UIView {
            return collectTexts(from: view)
        }

        if let accessibilityElement = element as? UIAccessibilityElement {
            var result: [String] = []
            if let label = accessibilityElement.accessibilityLabel, !label.isEmpty {
                result.append(label)
            }
            if let value = accessibilityElement.accessibilityValue, !value.isEmpty {
                result.append(value)
            }
            return result
        }

        return []
    }
}
