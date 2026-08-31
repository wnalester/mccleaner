import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .termsGate:
                TermsGateView()
            case .welcome:
                WelcomeView()
            case .scanning(let text):
                ScanningView(progressText: text)
            case .results, .confirming:
                ResultsView()
            case .paywall(let error):
                PlanPickerView(paymentError: error)
            case .verifyingPayment:
                VerifyingPaymentView()
            case .cleaning(let text):
                CleaningView(progressText: text)
            case .done(let freed, let failures):
                DoneView(freedBytes: freed, failures: failures)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
        .onOpenURL { url in appState.handleIncomingURL(url) }
    }

    private var phaseKey: Int {
        switch appState.phase {
        case .termsGate: return -1
        case .welcome: return 0
        case .scanning: return 1
        case .results, .confirming: return 2
        case .paywall: return 3
        case .verifyingPayment: return 4
        case .cleaning: return 5
        case .done: return 6
        }
    }
}
