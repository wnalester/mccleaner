import Foundation
import CoreText

/// Registers the app's two bundled variable fonts (Bricolage Grotesque for display text,
/// Hanken Grotesk for body copy — the same pair used on the marketing site, so the app and
/// the website read as one product) so `Font.custom` can find them by PostScript/family name.
/// Falls back to the system font automatically if registration ever fails for some reason.
enum FontRegistration {
    static let isRegistered: Bool = {
        let names = ["BricolageGrotesque", "HankenGrotesk"]
        var allOK = true
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                allOK = false
                continue
            }
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !success {
                let code = (error?.takeRetainedValue() as Error?).map { ($0 as NSError).code }
                // Already registered (e.g. a second AppState in the same process during
                // previews) isn't a real failure.
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    allOK = false
                }
            }
        }
        return allOK
    }()
}
