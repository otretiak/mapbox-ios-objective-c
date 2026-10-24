import UIKit
import MapboxMaps

@objc public enum TMBPuckBearingSource : Int {
    case heading
    case course
}

extension TMBPuckBearingSource {
    func swiftOnly() -> PuckBearing {
        switch(self) {
        case .heading: return .heading
        case .course: return .course
        }
    }
}
