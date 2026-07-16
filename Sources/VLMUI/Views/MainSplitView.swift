import SwiftUI

struct MainSplitView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left pane: Sidebar
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } content: {
            // Middle pane: Chat Area
            ChatAreaView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            // Right pane: Configuration Details
            RightPaneView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        }
        .navigationTitle("")
    }
}
