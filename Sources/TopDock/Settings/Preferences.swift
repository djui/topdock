import Foundation
import Observation

enum SortMode: String, CaseIterable, Identifiable {
    case recent
    case launch
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "Recently used"
        case .launch: "Launch order"
        case .name: "Name"
        }
    }
}

@MainActor
@Observable
final class Preferences {
    @ObservationIgnored var onChange: (() -> Void)?

    var iconSize: Double { didSet { save("iconSize", iconSize) } }
    var magnify: Bool { didSet { save("magnify", magnify) } }
    var magnification: Double { didSet { save("magnification", magnification) } }
    var maxSlots: Int { didSet { save("maxSlots", maxSlots) } }
    var sortMode: SortMode { didSet { save("sortMode", sortMode.rawValue) } }
    var showPinned: Bool { didSet { save("showPinned", showPinned) } }
    var showRecents: Bool { didSet { save("showRecents", showRecents) } }
    var recentsLimit: Int { didSet { save("recentsLimit", recentsLimit) } }
    var allDisplays: Bool { didSet { save("allDisplays", allDisplays) } }
    var hideWhenMenuBarHidden: Bool { didSet { save("hideWhenMenuBarHidden", hideWhenMenuBarHidden) } }
    var clickActiveHides: Bool { didSet { save("clickActiveHides", clickActiveHides) } }
    var fallbackWidth: Double { didSet { save("fallbackWidth", fallbackWidth) } }

    var hasLaunchedBefore: Bool {
        get { UserDefaults.standard.bool(forKey: "hasLaunchedBefore") }
        set { UserDefaults.standard.set(newValue, forKey: "hasLaunchedBefore") }
    }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "iconSize": 18.0,
            "magnify": true,
            "magnification": 1.8,
            "maxSlots": 16,
            "sortMode": SortMode.recent.rawValue,
            "showPinned": true,
            "showRecents": true,
            "recentsLimit": 4,
            "allDisplays": false,
            "hideWhenMenuBarHidden": true,
            "clickActiveHides": false,
            "fallbackWidth": 420.0,
        ])
        iconSize = d.double(forKey: "iconSize")
        magnify = d.bool(forKey: "magnify")
        magnification = d.double(forKey: "magnification")
        maxSlots = d.integer(forKey: "maxSlots")
        sortMode = SortMode(rawValue: d.string(forKey: "sortMode") ?? "") ?? .recent
        showPinned = d.bool(forKey: "showPinned")
        showRecents = d.bool(forKey: "showRecents")
        recentsLimit = d.integer(forKey: "recentsLimit")
        allDisplays = d.bool(forKey: "allDisplays")
        hideWhenMenuBarHidden = d.bool(forKey: "hideWhenMenuBarHidden")
        clickActiveHides = d.bool(forKey: "clickActiveHides")
        fallbackWidth = d.double(forKey: "fallbackWidth")
    }

    private func save(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        onChange?()
    }
}
