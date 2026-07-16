import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var googleAPIKey: String = ""
    @State private var openAIBaseUrl: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var currentSettingsProvider: String = "Google AI Studio"
    
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
                // Tab 1: API Configuration
                Form {
                    Section("Active Provider") {
                        Picker("Connector", selection: $appState.modelConfig.provider) {
                            Text("Google AI Studio").tag("Google AI Studio")
                            Text("OpenAI Compatible").tag("OpenAI Compatible")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: appState.modelConfig.provider) {
                            // Automatically update default model for provider
                            if appState.modelConfig.provider == "Google AI Studio" {
                                appState.modelConfig.modelName = "gemini-1.5-flash"
                            } else {
                                appState.modelConfig.modelName = "gpt-4o"
                            }
                            saveAllSettings()
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    if appState.modelConfig.provider == "Google AI Studio" {
                        Section("Google AI Studio Config") {
                            SecureField("Gemini API Key", text: $googleAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: googleAPIKey) { saveAllSettings() }
                            
                            Text("Retrieve your API key from Google AI Studio. This is saved locally in settings_db.json.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Section("OpenAI Compatible Config") {
                            TextField("Base URL", text: $openAIBaseUrl, prompt: Text("https://api.openai.com/v1"))
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: openAIBaseUrl) { saveAllSettings() }
                            
                            SecureField("API Key", text: $openAIAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: openAIAPIKey) { saveAllSettings() }
                            
                            Text("Use any OpenAI-compatible API gateway (e.g. DeepSeek, OpenRouter, Local Ollama/vLLM).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tabItem {
                    Label("Connectors & Keys", systemImage: "key.fill")
                }
                .padding()
                
                // Tab 2: Advanced Settings
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
            .frame(height: 280)
            
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
        .frame(width: 480, height: 380)
        .onAppear {
            loadStoredSettings()
        }
    }
    
    private func loadStoredSettings() {
        let (config, connectors) = StorageService.shared.loadSettings()
        
        // Sync app state if needed
        appState.modelConfig = config
        
        // Sync local text states
        googleAPIKey = connectors["Google AI Studio"] ?? ""
        openAIBaseUrl = connectors["OpenAI Compatible_base"] ?? ""
        openAIAPIKey = connectors["OpenAI Compatible"] ?? ""
    }
    
    private func saveAllSettings() {
        var connectors: [String: String] = [:]
        connectors["Google AI Studio"] = googleAPIKey
        connectors["OpenAI Compatible_base"] = openAIBaseUrl
        connectors["OpenAI Compatible"] = openAIAPIKey
        
        StorageService.shared.saveSettings(config: appState.modelConfig, connectors: connectors)
    }
}
