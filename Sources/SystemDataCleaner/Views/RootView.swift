import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .welcome:
                WelcomeView()
            case .scanning(let text):
                ScanningView(progressText: text)
            case .results, .confirming:
                ResultsView()
            case .cleaning(let text):
                CleaningView(progressText: text)
            case .done(let freed, let failures):
                DoneView(freedBytes: freed, failures: failures)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
    }

    private var phaseKey: Int {
        switch appState.phase {
        case .welcome: return 0
        case .scanning: return 1
        case .results, .confirming: return 2
        case .cleaning: return 3
        case .done: return 4
        }
    }
}
