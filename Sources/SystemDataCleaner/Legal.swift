import Foundation

/// Terms of Use content and acceptance tracking. Bump `termsVersion` any time the text
/// changes — that forces every user (even ones who already agreed to an older version) to
/// see and re-accept the gate before their next scan.
///
/// NOT a substitute for an actual lawyer reviewing this before the app is sold to the
/// public — this is a solid, standard-form draft covering the bases real commercial
/// software EULAs cover, not a guarantee against every possible claim.
enum Legal {
    static let termsVersion = "1.0"

    static let shortDisclaimer = "SDC scans your Mac, and — only if you choose, and only after you pay — deletes what you select. You are solely responsible for reviewing everything it finds and everything you select before anything runs. Back up anything important first. SDC is provided \u{201C}as is,\u{201D} with no warranty, and its developer is not liable for any data loss or damage arising from your use of it."

    static let fullTermsText = """
    Terms of Use — SDC (System Data Cleaner)

    Last updated: 2026-08-31 · Version \(termsVersion)

    Please read this before using SDC. By clicking "I Agree & Continue," you accept every term below.

    1. What SDC does
    SDC scans your Mac and reports on files and folders it identifies as part of macOS's "System Data" storage category. If you choose to, and after paying the applicable fee, SDC will delete or otherwise remove items you have personally selected. The Safe / Caution / Advanced labels SDC shows are informational only — they are not a guarantee that any specific item is safe to remove on your specific Mac, in your specific configuration, workflow, or use case.

    2. Your responsibility
    You are solely responsible for reviewing everything SDC finds, and for deciding what — if anything — to select for removal. You are solely responsible for maintaining your own backups of anything important before using SDC's cleanup feature. SDC's developer has no way to know what data matters to you, and makes no representation that any action SDC offers is appropriate for your situation.

    3. No warranty
    SDC is provided "AS IS" and "AS AVAILABLE," without warranty of any kind, express or implied, including without limitation the implied warranties of merchantability, fitness for a particular purpose, and non-infringement. The developer does not warrant that SDC will be error-free, uninterrupted, or that any action will produce the result you expect.

    4. Limitation of liability
    To the maximum extent permitted by applicable law, in no event will the developer of SDC be liable for any direct, indirect, incidental, special, consequential, or exemplary damages — including without limitation loss of data, loss of profits, or the cost of substitute services — arising out of or in connection with your use of, or inability to use, SDC, even if advised of the possibility of such damages.

    5. Assumption of risk
    Deleting or modifying files on a computer carries inherent risk. By using SDC's cleanup feature, you voluntarily and knowingly assume that risk.

    6. Indemnification
    You agree to indemnify and hold harmless SDC's developer from any claim, demand, loss, or damages, including reasonable legal fees, arising out of your use of SDC or your violation of these terms.

    7. Payments and your right of withdrawal
    Cleanup actions cost \(PurchaseConfig.priceLabel) per use, charged at the time you request a cleanup. By requesting a cleanup, you expressly ask that SDC begin performing the service immediately. You acknowledge that, once a cleanup has been fully performed, you lose any statutory right of withdrawal or cooling-off period that might otherwise apply to a digital service or digital content under applicable consumer protection law (for EU consumers, this reflects Directive 2011/83/EU on consumer rights, Article 16(m)).

    8. Your authority to use SDC on this computer
    You represent that you own this computer, or otherwise have full legal authority to scan and modify it — for example, that using SDC does not violate an employer's IT policy or any other agreement or law that applies to you.

    9. Changes to these terms
    These terms may be updated from time to time. A meaningful change will show this gate again before your next scan.

    10. Governing law
    [To be finalized — the app's operator will specify the governing jurisdiction here before public launch.]

    11. Contact
    [Support contact to be added.]
    """

    static var acceptedVersion: String? {
        UserDefaults.standard.string(forKey: "AcceptedTermsVersion")
    }

    static var hasAcceptedCurrentTerms: Bool {
        acceptedVersion == termsVersion
    }

    static func recordAcceptance() {
        UserDefaults.standard.set(termsVersion, forKey: "AcceptedTermsVersion")
        UserDefaults.standard.set(Date(), forKey: "AcceptedTermsDate")
    }
}
