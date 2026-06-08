import ComposableArchitecture
import SwiftUI

@main
struct SwipeyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(initialState: SwipeFeature.State()) {
                    SwipeFeature()
                }
            )
        }
    }
}
