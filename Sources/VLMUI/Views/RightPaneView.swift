import SwiftUI

struct RightPaneView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: System Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Label("System Instructions", systemImage: "macpro.gen1")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $appState.systemInstruction)
                        .font(.system(.body, design: .monospaced))
                        .padding(6)
                        .frame(height: 140)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: appState.systemInstruction) {
                            appState.saveWorkspace()
                        }
                }
                
                Divider()
                
                // Section 2: Model Tuning Parameters
                VStack(alignment: .leading, spacing: 14) {
                    Label("Parameters", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Temperature
                    ParameterSlider(
                        title: "Temperature",
                        value: $appState.modelConfig.temperature,
                        range: 0.0...2.0,
                        step: 0.05,
                        format: "%.2f",
                        onChange: appState.saveWorkspace
                    )
                    
                    // Top P
                    ParameterSlider(
                        title: "Top P",
                        value: $appState.modelConfig.topP,
                        range: 0.0...1.0,
                        step: 0.05,
                        format: "%.2f",
                        onChange: appState.saveWorkspace
                    )
                    
                    // Top K
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Top K")
                                .font(.body)
                            Spacer()
                            Text("\(appState.modelConfig.topK)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Stepper(value: $appState.modelConfig.topK, in: 1...100) {
                            Slider(value: Binding(
                                get: { Double(appState.modelConfig.topK) },
                                set: { appState.modelConfig.topK = Int($0) }
                            ), in: 1.0...100.0, step: 1.0)
                        }
                        .onChange(of: appState.modelConfig.topK) {
                            appState.saveWorkspace()
                        }
                    }
                    
                    // Min P
                    ParameterSlider(
                        title: "Min P",
                        value: $appState.modelConfig.minP,
                        range: 0.0...1.0,
                        step: 0.01,
                        format: "%.2f",
                        onChange: appState.saveWorkspace
                    )
                    
                    // Repeat Penalty
                    ParameterSlider(
                        title: "Repeat Penalty",
                        value: $appState.modelConfig.repeatPenalty,
                        range: 0.5...2.0,
                        step: 0.05,
                        format: "%.2f",
                        onChange: appState.saveWorkspace
                    )
                }
                
                Divider()
                
                // Section 3: Model Context Protocol (MCP) Tools
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("MCP Tools", systemImage: "wrench.and.screwdriver.fill")
                            .font(.headline)
                        Spacer()
                        Button(action: reloadMCPTools) {
                            Image(systemName: "arrow.clockwise")
                                .help("Reload mcp.json")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Configured via mcp.json in workspace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if appState.mcpTools.isEmpty {
                        VStack {
                            Text("No MCP Servers Loaded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(appState.mcpTools) { tool in
                                MCPToolRowView(tool: tool, onToggle: { isEnabled in
                                    if let idx = appState.mcpTools.firstIndex(where: { $0.id == tool.id }) {
                                        appState.mcpTools[idx].isEnabled = isEnabled
                                        // Save or update app state
                                    }
                                }, onPermissionChange: { newPerm in
                                    if let idx = appState.mcpTools.firstIndex(where: { $0.id == tool.id }) {
                                        appState.mcpTools[idx].permission = newPerm
                                        // Save or update app state
                                    }
                                })
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            reloadMCPTools()
        }
    }
    
    private func reloadMCPTools() {
        appState.mcpTools = StorageService.shared.readMCPTools()
    }
}

// MARK: - Parameter Slider Subview

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .onChange(of: value) {
                    onChange()
                }
        }
    }
}

// MARK: - MCP Tool Row View

struct MCPToolRowView: View {
    let tool: MCPTool
    var onToggle: (Bool) -> Void
    var onPermissionChange: (MCPTool.PermissionType) -> Void
    
    @State private var isEnabled: Bool
    @State private var permission: MCPTool.PermissionType
    
    init(tool: MCPTool, onToggle: @escaping (Bool) -> Void, onPermissionChange: @escaping (MCPTool.PermissionType) -> Void) {
        self.tool = tool
        self.onToggle = onToggle
        self.onPermissionChange = onPermissionChange
        self._isEnabled = State(initialValue: tool.isEnabled)
        self._permission = State(initialValue: tool.permission)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .fontWeight(.semibold)
                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: isEnabled) {
                        onToggle(isEnabled)
                    }
            }
            
            if isEnabled {
                HStack(spacing: 8) {
                    Text("Permission:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $permission) {
                        ForEach(MCPTool.PermissionType.allCases, id: \.self) { perm in
                            Text(perm.rawValue).tag(perm)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .onChange(of: permission) {
                        onPermissionChange(permission)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
