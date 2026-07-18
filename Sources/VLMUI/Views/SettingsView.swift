import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var selectedProviderId: UUID? = nil
    @State private var isFetchingModels = false
    @State private var fetchError: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Header
            HStack {
                Text("VLMUI Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab View for Configuration
            TabView {
                // Tab 1: Providers Master-Detail
                HStack(spacing: 0) {
                    // Left Column: List of Providers
                    VStack(alignment: .leading, spacing: 0) {
                        List(selection: $selectedProviderId) {
                            ForEach(appState.providers) { provider in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(provider.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(provider.isEnabled ? .primary : .secondary)
                                        Text(provider.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !provider.isEnabled {
                                        Text("Off")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(provider.id)
                            }
                        }
                        .listStyle(.sidebar)
                        
                        Divider()
                        
                        // Add provider button
                        HStack {
                            Button(action: {
                                let newProvider = ProviderConfig(
                                    name: "Custom OpenAI",
                                    type: .openai,
                                    endpointUrl: "http://localhost:11434/v1"
                                )
                                appState.providers.append(newProvider)
                                selectedProviderId = newProvider.id
                                saveAllSettings()
                            }) {
                                Label("Add Provider", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                    .frame(width: 200)
                    
                    Divider()
                    
                    // Right Column: Detail View
                    VStack(spacing: 0) {
                        if let selectedId = selectedProviderId,
                           let index = appState.providers.firstIndex(where: { $0.id == selectedId }) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Header details
                                    HStack {
                                        Text(appState.providers[index].name.isEmpty ? "Provider Settings" : appState.providers[index].name)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        Spacer()
                                        
                                        Toggle("Active", isOn: $appState.providers[index].isEnabled)
                                            .toggleStyle(.switch)
                                            .controlSize(.small)
                                            .onChange(of: appState.providers[index].isEnabled) { saveAllSettings() }
                                    }
                                    
                                    Form {
                                        TextField("Name", text: $appState.providers[index].name)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: appState.providers[index].name) { saveAllSettings() }
                                        
                                        Picker("Type", selection: Binding(
                                            get: { appState.providers[index].type },
                                            set: { newType in
                                                let oldType = appState.providers[index].type
                                                if oldType != newType {
                                                    appState.providers[index].type = newType
                                                    if newType == .google {
                                                        appState.providers[index].endpointUrl = "https://generativelanguage.googleapis.com"
                                                    } else {
                                                        appState.providers[index].endpointUrl = "https://api.openai.com/v1"
                                                    }
                                                    saveAllSettings()
                                                }
                                            }
                                        )) {
                                            ForEach(ProviderType.allCases, id: \.self) { type in
                                                Text(type.rawValue).tag(type)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        
                                        TextField("Endpoint URL", text: $appState.providers[index].endpointUrl)
                                            .textFieldStyle(.roundedBorder)
                                            .disabled(appState.providers[index].type == .google)
                                            .onChange(of: appState.providers[index].endpointUrl) { saveAllSettings() }
                                        
                                        SecureField("API Key", text: $appState.providers[index].apiKey)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: appState.providers[index].apiKey) { saveAllSettings() }
                                    }
                                    
                                    Divider()
                                    
                                    // Fetch Models Section
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Available Models")
                                                .font(.headline)
                                            Spacer()
                                            
                                            if isFetchingModels {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Button(action: {
                                                    let p = appState.providers[index]
                                                    Task {
                                                        await fetchModels(for: p)
                                                    }
                                                }) {
                                                    Label("Fetch Models", systemImage: "arrow.clockwise")
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                        
                                        if let err = fetchError {
                                            Text(err)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        
                                        if appState.providers[index].availableModels.isEmpty {
                                            Text("No models fetched yet. Click 'Fetch Models' to load available models.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.vertical, 8)
                                        } else {
                                            // Scrollable checkbox list
                                            VStack(alignment: .leading, spacing: 4) {
                                                ScrollView {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        ForEach(appState.providers[index].availableModels, id: \.self) { model in
                                                            let isChecked = appState.providers[index].selectedModels.contains(model)
                                                            Toggle(model, isOn: Binding(
                                                                get: { isChecked },
                                                                set: { val in
                                                                    if val {
                                                                        if !appState.providers[index].selectedModels.contains(model) {
                                                                            appState.providers[index].selectedModels.append(model)
                                                                        }
                                                                    } else {
                                                                        appState.providers[index].selectedModels.removeAll(where: { $0 == model })
                                                                    }
                                                                    saveAllSettings()
                                                                }
                                                            ))
                                                            .toggleStyle(.checkbox)
                                                        }
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .frame(minHeight: 80, maxHeight: 200)
                                            }
                                            .padding(6)
                                            .background(Color.primary.opacity(0.04))
                                            .cornerRadius(6)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Delete Provider Button
                                    HStack {
                                        Spacer()
                                        Button(role: .destructive, action: {
                                            appState.providers.remove(at: index)
                                            selectedProviderId = appState.providers.first?.id
                                            saveAllSettings()
                                        }) {
                                            Label("Delete Provider", systemImage: "trash")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding()
                            }
                        } else {
                            VStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "server.rack")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("Select a provider on the left to configure")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tabItem {
                    Label("Providers & Models", systemImage: "server.rack")
                }
                
                // Tab 2: Workspace Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workspace Settings")
                        .font(.headline)
                    
                    Text("Current storage root:")
                        .font(.body)
                    
                    Text("/Users/bran/src/play/vlmui")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                .tabItem {
                    Label("Workspace", systemImage: "folder.fill")
                }
                .padding()
            }
            
            Divider()
            
            // Footer Control
            HStack {
                Spacer()
                Button("Done") {
                    appState.isSettingsPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 700, height: 520)
        .onAppear {
            if selectedProviderId == nil {
                selectedProviderId = appState.providers.first?.id
            }
        }
    }
    
    private func fetchModels(for provider: ProviderConfig) async {
        isFetchingModels = true
        fetchError = nil
        
        do {
            var models: [String] = []
            
            switch provider.type {
            case .google:
                let key = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else {
                    throw NSError(domain: "Settings", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is required to fetch Google models."])
                }
                guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
                    throw NSError(domain: "Settings", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Google API URL."])
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
                    throw NSError(domain: "Settings", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
                }
                
                struct GoogleModelsResponse: Codable {
                    struct GoogleModelItem: Codable {
                        let name: String
                    }
                    let models: [GoogleModelItem]
                }
                
                let decoded = try JSONDecoder().decode(GoogleModelsResponse.self, from: data)
                models = decoded.models.map { item in
                    if item.name.hasPrefix("models/") {
                        return String(item.name.dropFirst(7))
                    }
                    return item.name
                }
                
            case .openai:
                let urlString = provider.endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let baseUrl = URL(string: urlString) else {
                    throw NSError(domain: "Settings", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL."])
                }
                let modelsUrl = baseUrl.appendingPathComponent("models")
                var request = URLRequest(url: modelsUrl)
                request.httpMethod = "GET"
                
                let key = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
                    throw NSError(domain: "Settings", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
                }
                
                struct OpenAIModelsResponse: Codable {
                    struct OpenAIModelItem: Codable {
                        let id: String
                    }
                    let data: [OpenAIModelItem]
                }
                
                let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
                models = decoded.data.map { $0.id }.sorted()
            }
            
            if let idx = appState.providers.firstIndex(where: { $0.id == provider.id }) {
                appState.providers[idx].availableModels = models
                let existingSelected = Set(appState.providers[idx].selectedModels)
                appState.providers[idx].selectedModels = models.filter { existingSelected.contains($0) }
                saveAllSettings()
            }
            
        } catch {
            print("Fetch models failed: \(error)")
            fetchError = error.localizedDescription
        }
        
        isFetchingModels = false
    }
    
    private func saveAllSettings() {
        var connectors: [String: String] = [:]
        if let googleProvider = appState.providers.first(where: { $0.type == .google }) {
            connectors["Google AI Studio"] = googleProvider.apiKey
        }
        if let openaiProvider = appState.providers.first(where: { $0.type == .openai }) {
            connectors["OpenAI Compatible_base"] = openaiProvider.endpointUrl
            connectors["OpenAI Compatible"] = openaiProvider.apiKey
        }
        
        StorageService.shared.saveSettings(
            config: appState.modelConfig,
            connectors: connectors,
            providers: appState.providers
        )
    }
}
