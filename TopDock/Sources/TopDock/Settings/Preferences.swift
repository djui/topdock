import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    @ObservationIgnored var onChange: (() -> Void)?

    var iconSize: Double { didSet { save("iconSize", iconSize) } }
    var iconSpacing: Double { didSet { save("iconSpacing", iconSpacing) } }
    var magnify: Bool { didSet { save("magnify", magnify) } }
    var showBadges: Bool { didSet { save("showBadges", showBadges) } }
    var magnification: Double { didSet { save("magnification", magnification) } }
    var maxSlots: Int { didSet { save("maxSlots", maxSlots) } }
    var allDisplays: Bool { didSet { save("allDisplays", allDisplays) } }
    var hideWhenMenuBarHidden: Bool { didSet { save("hideWhenMenuBarHidden", hideWhenMenuBarHidden) } }
    var clickActiveHides: Bool { didSet { save("clickActiveHides", clickActiveHides) } }
    var fallbackWidth: Double { didSet { save("fallbackWidth", fallbackWidth) } }
    var showMenuBarIcon: Bool { didSet { save("showMenuBarIcon", showMenuBarIcon) } }

    var hasLaunchedBefore: Bool {
        get { UserDefaults.standard.bool(forKey: "hasLaunchedBefore") }
        set { UserDefaults.standard.set(newValue, forKey: "hasLaunchedBefore") }
    }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "iconSize": 18.0,
            "iconSpacing": 2.0,
            "magnify": true,
            "showBadges": true,
            "magnification": 1.8,
            "maxSlots": 40,
            "allDisplays": false,
            "hideWhenMenuBarHidden": true,
            "clickActiveHides": false,
            "fallbackWidth": 420.0,
            "showMenuBarIcon": true,
        ])
        iconSize = d.double(forKey: "iconSize")
        iconSpacing = d.double(forKey: "iconSpacing")
        magnify = d.bool(forKey: "magnify")
        showBadges = d.bool(forKey: "showBadges")
        magnification = d.double(forKey: "magnification")
        maxSlots = d.integer(forKey: "maxSlots")
        allDisplays = d.bool(forKey: "allDisplays")
        hideWhenMenuBarHidden = d.bool(forKey: "hideWhenMenuBarHidden")
        clickActiveHides = d.bool(forKey: "clickActiveHides")
        fallbackWidth = d.double(forKey: "fallbackWidth")
        showMenuBarIcon = d.bool(forKey: "showMenuBarIcon")
    }

    private func save(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        onChange?()
    }
}
