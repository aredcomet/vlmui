import SwiftUI

struct MainSplitView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left pane: Sidebar
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            // Main content pane containing Chat and collapsible Right Pane
            HStack(spacing: 0) {
                ChatAreaView()
                
                if appState.isRightPaneVisible {
                    Divider()
                    RightPaneView()
                        .frame(width: 300)
                        .transition(.move(edge: .trailing))
                }
            }
            .navigationTitle("")
        }
    }
}
