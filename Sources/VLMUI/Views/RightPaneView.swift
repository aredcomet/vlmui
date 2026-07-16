import SwiftUI

struct RightPaneView: View {
    @EnvironmentObject var appState: AppState
    
    // Collapsible section expansion states
    @State private var isSystemInstructionsExpanded = true
    @State private var isParametersExpanded = true
    @State private var isMCPToolsExpanded = true
    
    // System Instructions height resizing state
    @State private var systemInstructionHeight: CGFloat = 120
    @State private var dragStartHeight: CGFloat = 120
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                
                // SECTION 1: System Instructions
                DisclosureGroup(isExpanded: $isSystemInstructionsExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextEditor(text: $appState.systemInstruction)
                            .font(.system(.body, design: .monospaced))
                            .padding(6)
                            .frame(height: systemInstructionHeight)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .onChange(of: appState.systemInstruction) {
                                appState.saveWorkspace()
                            }
                        
                        // Resizing Drag Handle
                        HStack {
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if value.translation == .zero {
                                                dragStartHeight = systemInstructionHeight
                                            }
                                            systemInstructionHeight = max(60, dragStartHeight + value.translation.height)
                                        }
                                )
                            Spacer()
                        }
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(3)
                    }
                    .padding(.top, 6)
                } label: {
                    Label("System Instructions", systemImage: "macpro.gen1")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // SECTION 2: Model Tuning Parameters
                DisclosureGroup(isExpanded: $isParametersExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        
                        // Temperature (Default: 0.7)
                        ParameterControlView(
                            title: "Temperature",
                            isEnabled: Binding(
                                get: { appState.modelConfig.isTemperatureEnabled ?? true },
                                set: { appState.modelConfig.isTemperatureEnabled = $0 }
                            ),
                            value: $appState.modelConfig.temperature,
                            range: 0.0...2.0,
                            step: 0.05,
                            format: "%.2f",
                            defaultValue: 0.7,
                            onChange: appState.saveWorkspace
                        )
                        
                        // Top P Sampling (Default: 0.95)
                        ParameterControlView(
                            title: "Top P Sampling",
                            isEnabled: Binding(
                                get: { appState.modelConfig.isTopPEnabled ?? true },
                                set: { appState.modelConfig.isTopPEnabled = $0 }
                            ),
                            value: $appState.modelConfig.topP,
                            range: 0.0...1.0,
                            step: 0.05,
                            format: "%.2f",
                            defaultValue: 0.95,
                            onChange: appState.saveWorkspace
                        )
                        
                        // Top K Sampling (Default: 40)
                        IntParameterControlView(
                            title: "Top K Sampling",
                            isEnabled: Binding(
                                get: { appState.modelConfig.isTopKEnabled ?? true },
                                set: { appState.modelConfig.isTopKEnabled = $0 }
                            ),
                            value: $appState.modelConfig.topK,
                            range: 1.0...100.0,
                            step: 1.0,
                            defaultValue: 40,
                            onChange: appState.saveWorkspace
                        )
                        
                        // Min P Sampling (Default: 0.05)
                        ParameterControlView(
                            title: "Min P Sampling",
                            isEnabled: Binding(
                                get: { appState.modelConfig.isMinPEnabled ?? false },
                                set: { appState.modelConfig.isMinPEnabled = $0 }
                            ),
                            value: $appState.modelConfig.minP,
                            range: 0.0...1.0,
                            step: 0.01,
                            format: "%.2f",
                            defaultValue: 0.05,
                            onChange: appState.saveWorkspace
                        )
                        
                        // Repeat Penalty (Default: 1.0)
                        ParameterControlView(
                            title: "Repeat Penalty",
                            isEnabled: Binding(
                                get: { appState.modelConfig.isRepeatPenaltyEnabled ?? false },
                                set: { appState.modelConfig.isRepeatPenaltyEnabled = $0 }
                            ),
                            value: $appState.modelConfig.repeatPenalty,
                            range: 0.5...2.0,
                            step: 0.05,
                            format: "%.2f",
                            defaultValue: 1.0,
                            onChange: appState.saveWorkspace
                        )
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Sampling Parameters", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // SECTION 3: MCP Tools Section
                DisclosureGroup(isExpanded: $isMCPToolsExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Configured via mcp.json in workspace")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: reloadMCPServers) {
                                Image(systemName: "arrow.clockwise")
                                    .help("Reload mcp.json")
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if appState.mcpServers.isEmpty {
                            Text("No MCP Servers Loaded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(appState.mcpServers) { server in
                                    MCPServerRowView(server: server)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Label("MCP Tools", systemImage: "wrench.and.screwdriver.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            reloadMCPServers()
        }
    }
    
    private func reloadMCPServers() {
        appState.mcpServers = StorageService.shared.readMCPServers()
    }
}

// MARK: - Double Parameter Control View

struct ParameterControlView: View {
    let title: String
    @Binding var isEnabled: Bool
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let defaultValue: Double
    var onChange: () -> Void
    
    @State private var textInput: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Checkbox
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.checkbox)
                    .onChange(of: isEnabled) {
                        onChange()
                    }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Spacer()
                
                if isEnabled {
                    // Trash bin (Reset)
                    Button(action: {
                        value = defaultValue
                        textInput = String(format: format, defaultValue)
                        onChange()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    // Manual numeric input
                    TextField("", text: $textInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                        .multilineTextAlignment(.trailing)
                        .focused($isFocused)
                        .onSubmit {
                            submitTextValue()
                        }
                        .onChange(of: isFocused) {
                            if !isFocused {
                                submitTextValue()
                            }
                        }
                }
            }
            
            if isEnabled {
                // Slider
                Slider(value: $value, in: range, step: step)
                    .onChange(of: value) {
                        if !isFocused {
                            textInput = String(format: format, value)
                        }
                        onChange()
                    }
            }
        }
        .onAppear {
            textInput = String(format: format, value)
        }
        .onChange(of: value) {
            if !isFocused {
                textInput = String(format: format, value)
            }
        }
    }
    
    private func submitTextValue() {
        if let parsed = Double(textInput), range.contains(parsed) {
            value = parsed
            onChange()
        } else {
            textInput = String(format: format, value)
        }
    }
}

// MARK: - Integer Parameter Control View

struct IntParameterControlView: View {
    let title: String
    @Binding var isEnabled: Bool
    @Binding var value: Int
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Int
    var onChange: () -> Void
    
    @State private var textInput: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.checkbox)
                    .onChange(of: isEnabled) {
                        onChange()
                    }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Spacer()
                
                if isEnabled {
                    Button(action: {
                        value = defaultValue
                        textInput = "\(defaultValue)"
                        onChange()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    TextField("", text: $textInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                        .multilineTextAlignment(.trailing)
                        .focused($isFocused)
                        .onSubmit {
                            submitTextValue()
                        }
                        .onChange(of: isFocused) {
                            if !isFocused {
                                submitTextValue()
                            }
                        }
                }
            }
            
            if isEnabled {
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ), in: range, step: step)
                .onChange(of: value) {
                    if !isFocused {
                        textInput = "\(value)"
                    }
                    onChange()
                }
            }
        }
        .onAppear {
            textInput = "\(value)"
        }
        .onChange(of: value) {
            if !isFocused {
                textInput = "\(value)"
            }
        }
    }
    
    private func submitTextValue() {
        if let parsed = Int(textInput), range.contains(Double(parsed)) {
            value = parsed
            onChange()
        } else {
            textInput = "\(value)"
        }
    }
}

// MARK: - MCP Server Row View (High-Fidelity)

struct MCPServerRowView: View {
    @ObservedObject var server: MCPServerState
    @State private var isExpanded = true
    
    var body: some View {
        let modeText = server.permissionMode == .perTool ? "Per Tool" : "Always Allow All"
        
        return VStack(alignment: .leading, spacing: 6) {
            // Header: Toggle, Server Name, Badge, Actions Menu, Expand chevron
            HStack(spacing: 8) {
                Toggle("", isOn: $server.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Text(server.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                // Hammer icon inside badge
                HStack(spacing: 3) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(10)
                
                Spacer()
                
                // Server Options Menu (...)
                Menu {
                    Button(action: { /* Pin action */ }) {
                        Label("Pin to chat input", systemImage: "pin")
                    }
                    Button(action: { /* Restart action */ }) {
                        Label("Force Restart", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button(role: .destructive, action: { /* Uninstall action */ }) {
                        Label("Uninstall", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                
                // Collapse Chevron
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            
            // Expanded Server Tool List
            if server.isEnabled && isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Subheader: Tools refresh and Permission Mode picker
                    HStack {
                        Label("Tools", systemImage: "hammer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: { /* Refresh tools action */ }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Per Tool / Always Allow All picker
                        Menu {
                            Button("Per-tool permissions") {
                                server.permissionMode = .perTool
                            }
                            Button("Always allow all tools") {
                                server.permissionMode = .alwaysAllowAll
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(modeText)
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 2)
                    
                    // List of Tools
                    ForEach(server.tools.indices, id: \.self) { idx in
                        let tool = server.tools[idx]
                        HStack {
                            // Checkbox
                            Toggle("", isOn: $server.tools[idx].isEnabled)
                                .toggleStyle(.checkbox)
                            
                            Text(tool.name)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(tool.isEnabled ? .primary : .secondary)
                            
                            Spacer()
                            
                            if tool.isEnabled && server.permissionMode == .perTool {
                                // Tool Permission selection
                                Menu {
                                    Button("Ask before running") {
                                        server.tools[idx].permission = .ask
                                    }
                                    Button("Always allow") {
                                        server.tools[idx].permission = .alwaysAllowed
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(tool.permission == .ask ? "Ask" : "Allow")
                                        Image(systemName: "chevron.up.chevron.down")
                                    }
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.vertical, 2)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
