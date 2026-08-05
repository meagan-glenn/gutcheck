import SwiftUI

@main
struct GutCheckApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .fontDesign(.rounded)
                .tint(DS.brand)
                .accentColor(DS.brand)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if store.data.hasOnboarded {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            }
        } else {
            OnboardingFlow()
        }
    }
}
