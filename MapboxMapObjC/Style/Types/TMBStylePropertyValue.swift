import UIKit
import MapboxCoreMaps

@objc public enum TMBStylePropertyValueKind: Int {
    case undefined = 0
    case constant = 1
    case expression = 2
    case transition = 3
}

@objc open class TMBStylePropertyValue: NSObject {
    @objc public let value: Any?
    @objc public let kind: TMBStylePropertyValueKind

    public init(_ origin: StylePropertyValue) {
        self.value = origin.value
        self.kind = TMBStylePropertyValueKind(rawValue: origin.kind.rawValue) ?? .undefined
    }
}

extension StylePropertyValue {
    func wrap() -> TMBStylePropertyValue {
        TMBStylePropertyValue(self)
    }
}
