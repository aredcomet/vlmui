import SwiftUI
import AppKit

struct ChatAreaView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    @State private var selectedImageData: Data? = nil
    @State private var selectedImageMimeType: String? = nil
    
    // UI states for editing messages
    @State private var editingMessageId: UUID? = nil
    @State private var editText: String = ""
    
    // State for loading response
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 2. Chat Area scrollview
            if let thread = currentThread {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(thread.messages.enumerated()), id: \.element.id) { index, msg in
                                MessageBubbleView(
                                    message: msg,
                                    isLast: index == thread.messages.count - 1,
                                    onEdit: {
                                        editingMessageId = msg.id
                                        editText = msg.content.textString
                                    },
                                    onDelete: {
                                        deleteMessage(msg, in: thread)
                                    },
                                    onRetry: {
                                        retryGeneration(in: thread)
                                    },
                                    onAlternativeChanged: { newIndex in
                                        changeAlternative(message: msg, toIndex: newIndex, in: thread)
                                    },
                                    onBranch: {
                                        branchConversation(atIndex: index, in: thread)
                                    }
                                )
                                .id(msg.id)
                            }
                            
                            if isGenerating {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Generating response...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.primary.opacity(0.02))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: thread.messages.count) {
                        if let last = thread.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "message.and.waveform")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Chat Selected")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Choose a conversation from the sidebar or click '+' to start a new chat.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            // 3. Message Input Panel
            if currentThread != nil {
                VStack(spacing: 8) {
                    // Image attachment preview if any
                    if let imgData = selectedImageData {
                        HStack {
                            if let nsImg = NSImage(data: imgData) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(6)
                                    .overlay(
                                        Button(action: {
                                            selectedImageData = nil
                                            selectedImageMimeType = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 25, y: -25)
                                    )
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        Button(action: selectImageFile) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Attach Image")
                        
                        TextField("Type message...", text: $inputText, axis: .vertical)
                            .lineLimit(1...6)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor((inputText.isEmpty || appState.modelConfig.modelName == "Select model") ? .secondary : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled((inputText.isEmpty && selectedImageData == nil) || appState.modelConfig.modelName == "Select model")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
        }
        .toolbar {
            if currentThread != nil {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 16) {
                        // Toolgroup
                        HStack(spacing: 8) {
                            Button(action: {
                                appState.parentFolderForNewFolder = nil
                                appState.showNewFolderDialog = true
                            }) {
                                Image(systemName: "folder.badge.plus")
                            }
                            .help("New Folder")
                            
                            Button(action: {
                                appState.createNewChat(in: nil)
                            }) {
                                Image(systemName: "plus")
                            }
                            .help("New Chat")
                        }
                        
                        // Unified model selection Menu button
                        Menu {
                            Button("Select model") {
                                appState.modelConfig.modelName = "Select model"
                                appState.modelConfig.providerId = nil
                            }
                            
                            ForEach(appState.providers.filter { $0.isEnabled }) { provider in
                                Section(header: Text(provider.name)) {
                                    ForEach(provider.selectedModels, id: \.self) { model in
                                        Button(model) {
                                            selectModel(model, from: provider)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: providerIconName)
                                    .foregroundColor(.accentColor)
                                    .padding(.leading, 4)
                                
                                Text(appState.modelConfig.modelName)
                                    .padding(.trailing, 4)
                            }
                        }
                        .menuStyle(.button)
                        .frame(width: 170)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            appState.isRightPaneVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.right")
                    }
                    .help("Toggle Configuration Panel")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingMessageId != nil },
            set: { if !$0 { editingMessageId = nil } }
        )) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Message")
                    .font(.headline)
                
                TextEditor(text: $editText)
                    .frame(height: 120)
                    .border(Color.secondary.opacity(0.3))
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        editingMessageId = nil
                    }
                    Button("Save Changes") {
                        saveEditedMessage()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 400)
        }
    }
    
    // MARK: - Helper Computed Properties
    
    private var currentThread: ChatThread? {
        guard let selectedId = appState.selectedThreadId else { return nil }
        
        func findThread(in folders: [Folder]) -> ChatThread? {
            for folder in folders {
                if let thread = folder.chats.first(where: { $0.id == selectedId }) {
                    return thread
                }
                if let found = findThread(in: folder.subfolders) {
                    return found
                }
            }
            return nil
        }
        return findThread(in: appState.folders)
    }
    
    // MARK: - Actions
    
    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            if let url = panel.url, let data = try? Data(contentsOf: url) {
                selectedImageData = data
                selectedImageMimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
            }
        }
    }
    
    private func sendMessage() {
        guard appState.modelConfig.modelName != "Select model" else { return }
        guard let thread = currentThread else { return }
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || selectedImageData != nil else { return }
        
        // Assemble Content
        let content: MessageContent
        if let imgData = selectedImageData, let mime = selectedImageMimeType {
            let base64 = imgData.base64EncodedString()
            let imgUrl = "data:\(mime);base64,\(base64)"
            
            var parts: [ContentPart] = []
            if !trimmedText.isEmpty {
                parts.append(.text(trimmedText))
            }
            parts.append(.imageUrl(.init(url: imgUrl)))
            content = .multipart(parts)
        } else {
            content = .text(trimmedText)
        }
        
        // Add User Message
        let userMsg = Message(role: .user, content: content)
        thread.messages.append(userMsg)
        
        // Reset Inputs
        inputText = ""
        selectedImageData = nil
        selectedImageMimeType = nil
        
        // Save Work
        appState.saveWorkspace()
        
        // Run Completion
        runCompletion(in: thread)
    }
    
    private func runCompletion(in thread: ChatThread) {
        guard !isGenerating else { return }
        isGenerating = true
        
        let assistantMsg = Message(role: .assistant, content: .text(""))
        thread.messages.append(assistantMsg)
        
        let creds = getActiveProviderCredentials()
        
        LLMService.shared.runCompletion(
            providerType: creds.providerType,
            apiKey: creds.apiKey,
            baseUrl: creds.baseUrl,
            messages: Array(thread.messages.dropLast()), // send all messages except the assistant placeholder
            systemInstruction: appState.systemInstruction,
            config: appState.modelConfig,
            onToken: { token in
                if let index = thread.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                    let currentText = thread.messages[index].content.textString
                    thread.messages[index].content = .text(currentText + token)
                    appState.objectWillChange.send()
                }
            },
            onReasoningToken: { reasoningToken in
                if let index = thread.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                    let currentReasoning = thread.messages[index].reasoningContent ?? ""
                    thread.messages[index].reasoningContent = currentReasoning + reasoningToken
                    appState.objectWillChange.send()
                }
            },
            onMetrics: { metrics in
                if let index = thread.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                    thread.messages[index].metrics = metrics
                }
                self.isGenerating = false
                self.appState.saveWorkspace()
            },
            onError: { error in
                if let index = thread.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                    thread.messages[index].content = .text("Error: \(error.localizedDescription)")
                }
                self.isGenerating = false
            }
        )
    }
    
    private func retryGeneration(in thread: ChatThread) {
        guard !thread.messages.isEmpty, !isGenerating else { return }
        
        // Find last assistant message
        let lastIndex = thread.messages.count - 1
        let lastMsg = thread.messages[lastIndex]
        guard lastMsg.role == .assistant else { return }
        
        isGenerating = true
        
        // Save current response to alternatives if not already there
        var alternatives = lastMsg.alternativeContents ?? []
        if alternatives.isEmpty {
            alternatives.append(lastMsg.content)
        }
        
        // Prepare temporary content placeholder
        let newAlternativeIndex = alternatives.count
        alternatives.append(.text(""))
        
        thread.messages[lastIndex].alternativeContents = alternatives
        thread.messages[lastIndex].activeAlternativeIndex = newAlternativeIndex
        thread.messages[lastIndex].content = .text("")
        thread.messages[lastIndex].reasoningContent = nil
        
        let creds = getActiveProviderCredentials()
        
        LLMService.shared.runCompletion(
            providerType: creds.providerType,
            apiKey: creds.apiKey,
            baseUrl: creds.baseUrl,
            messages: Array(thread.messages.prefix(lastIndex)), // send up to user query
            systemInstruction: appState.systemInstruction,
            config: appState.modelConfig,
            onToken: { token in
                let currentText = thread.messages[lastIndex].content.textString
                thread.messages[lastIndex].content = .text(currentText + token)
                appState.objectWillChange.send()
            },
            onReasoningToken: { reasoningToken in
                let currentReasoning = thread.messages[lastIndex].reasoningContent ?? ""
                thread.messages[lastIndex].reasoningContent = currentReasoning + reasoningToken
                appState.objectWillChange.send()
            },
            onMetrics: { metrics in
                thread.messages[lastIndex].metrics = metrics
                
                // Update the active index and alternatives
                var currentAlts = thread.messages[lastIndex].alternativeContents ?? []
                if newAlternativeIndex < currentAlts.count {
                    currentAlts[newAlternativeIndex] = thread.messages[lastIndex].content
                }
                thread.messages[lastIndex].alternativeContents = currentAlts
                
                self.isGenerating = false
                self.appState.saveWorkspace()
            },
            onError: { error in
                thread.messages[lastIndex].content = .text("Error: \(error.localizedDescription)")
                self.isGenerating = false
            }
        )
    }
    
    private func changeAlternative(message: Message, toIndex newIndex: Int, in thread: ChatThread) {
        guard let alternatives = message.alternativeContents,
              newIndex >= 0 && newIndex < alternatives.count,
              let msgIndex = thread.messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        
        thread.messages[msgIndex].activeAlternativeIndex = newIndex
        thread.messages[msgIndex].content = alternatives[newIndex]
        appState.saveWorkspace()
    }
    
    private func saveEditedMessage() {
        guard let editingId = editingMessageId, let thread = currentThread else { return }
        
        if let idx = thread.messages.firstIndex(where: { $0.id == editingId }) {
            thread.messages[idx].content = .text(editText)
            
            // If it is user message and has assistant responses after it,
            // we delete the assistant responses after it and re-generate the completion
            if thread.messages[idx].role == .user {
                thread.messages = Array(thread.messages.prefix(idx + 1))
                runCompletion(in: thread)
            }
        }
        
        editingMessageId = nil
        appState.saveWorkspace()
    }
    
    private func deleteMessage(_ msg: Message, in thread: ChatThread) {
        if let idx = thread.messages.firstIndex(where: { $0.id == msg.id }) {
            thread.messages.remove(at: idx)
            appState.saveWorkspace()
        }
    }
    
    private func branchConversation(atIndex index: Int, in thread: ChatThread) {
        // Creates a new chat thread containing messages up to specified index
        let subMessages = Array(thread.messages.prefix(index + 1))
        let newBranch = ChatThread(title: "\(thread.title) (Branch)")
        newBranch.messages = subMessages
        newBranch.systemInstruction = thread.systemInstruction
        newBranch.modelConfig = thread.modelConfig
        
        // Find which folder contains current thread
        func addBranch(to folders: [Folder]) -> Bool {
            for folder in folders {
                if folder.chats.contains(where: { $0.id == thread.id }) {
                    folder.chats.append(newBranch)
                    return true
                }
                if addBranch(to: folder.subfolders) {
                    return true
                }
            }
            return false
        }
        
        _ = addBranch(to: appState.folders)
        appState.selectedThreadId = newBranch.id
        appState.saveWorkspace()
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: Message
    let isLast: Bool
    
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onRetry: () -> Void
    var onAlternativeChanged: (Int) -> Void
    var onBranch: () -> Void
    
    @State private var isHovering = false
    @State private var isThinkingExpanded = true
    
    private var parsedContent: (reasoning: String?, content: String) {
        let rawText = message.content.textString
        
        if let reasoning = message.reasoningContent, !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (reasoning, rawText)
        }
        
        guard let thinkRange = rawText.range(of: "<think>") else {
            return (nil, rawText)
        }
        
        let afterThink = rawText[thinkRange.upperBound...]
        if let endThinkRange = afterThink.range(of: "</think>") {
            let reasoning = String(afterThink[..<endThinkRange.lowerBound])
            let remainder = String(afterThink[endThinkRange.upperBound...])
            return (reasoning, remainder)
        } else {
            let reasoning = String(afterThink)
            return (reasoning, "")
        }
    }
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            // User vs Assistant Indicator Header
            HStack(spacing: 8) {
                if message.role == .user {
                    Spacer()
                    Text("You")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                } else {
                    Text(message.role == .assistant ? "Assistant" : "System")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Content Bubble
            HStack {
                if message.role == .user { Spacer() }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Image attachment inside message
                    if case .multipart(let parts) = message.content {
                        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                            switch part {
                            case .imageUrl(let imgPart):
                                ImageContainer(base64String: imgPart.url)
                            default:
                                EmptyView()
                            }
                        }
                    }
                    
                    let parsed = parsedContent
                    
                    if let reasoning = parsed.reasoning, !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "brain")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 10))
                                Text("Thinking Process")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(isThinkingExpanded ? 90 : 0))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isThinkingExpanded.toggle()
                                }
                            }
                            
                            if isThinkingExpanded {
                                Text(reasoning.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.bottom, 6)
                    }
                    
                    if !parsed.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsed.reasoning == nil {
                        Text(parsed.content)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ?
                    Color.accentColor.opacity(0.15) :
                    Color.primary.opacity(0.04)
                )
                .cornerRadius(12)
                
                if message.role != .user { Spacer() }
            }
            
            // Footer: Metrics and Alternative Selectors
            HStack(spacing: 12) {
                if message.role == .assistant {
                    // Metrics display
                    if let metrics = message.metrics {
                        HStack(spacing: 8) {
                            if let tfft = metrics.tfftMs {
                                Text("TFTT: \(Int(tfft))ms")
                            }
                            if let tps = metrics.tokensPerSecond {
                                Text(String(format: "%.1f t/s", tps))
                            }
                            if let count = metrics.tokenCount {
                                Text("\(count) tok")
                            }
                            if let duration = metrics.timeTaken {
                                Text(String(format: "%.2fs", duration))
                            }
                        }
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    }
                    
                    // Alternatives / Retry branch pagination
                    if let alternatives = message.alternativeContents, alternatives.count > 1 {
                        let activeIdx = message.activeAlternativeIndex ?? 0
                        HStack(spacing: 4) {
                            Button(action: {
                                if activeIdx > 0 { onAlternativeChanged(activeIdx - 1) }
                            }) {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            .disabled(activeIdx == 0)
                            
                            Text("\(activeIdx + 1)/\(alternatives.count)")
                                .font(.caption)
                            
                            Button(action: {
                                if activeIdx < alternatives.count - 1 { onAlternativeChanged(activeIdx + 1) }
                            }) {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.plain)
                            .disabled(activeIdx == alternatives.count - 1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Hover Options Menu
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: copyToClipboard) {
                            Image(systemName: "doc.on.doc")
                                .help("Copy Message")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .help("Edit Message")
                        }
                        .buttonStyle(.plain)
                        
                        if message.role == .assistant {
                            Button(action: onBranch) {
                                Image(systemName: "arrow.branch")
                                    .help("Branch Thread")
                            }
                            .buttonStyle(.plain)
                            
                            if isLast {
                                Button(action: onRetry) {
                                    Image(systemName: "arrow.clockwise")
                                        .help("Retry Response")
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .help("Delete Message")
                                }
                                .buttonStyle(.plain)
                            }
                        } else if message.role == .user {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .help("Delete Message")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                }
            }
            .frame(height: 20)
        }
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hover
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content.textString, forType: .string)
    }
}

// MARK: - Base64 Image Loader Helper

struct ImageContainer: View {
    let base64String: String
    
    var body: some View {
        if let nsImage = loadImage() {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .cornerRadius(6)
        } else {
            Text("Error loading image")
                .foregroundColor(.red)
        }
    }
    
    private func loadImage() -> NSImage? {
        let comps = base64String.components(separatedBy: ",")
        guard comps.count > 1,
              let data = Data(base64Encoded: comps[1]) else {
            return nil
        }
        return NSImage(data: data)
    }
}

// MARK: - ChatAreaView Provider Configuration Helpers

extension ChatAreaView {
    private var providerIconName: String {
        guard appState.modelConfig.modelName != "Select model" else { return "cpu" }
        if let providerId = appState.modelConfig.providerId,
           let provider = appState.providers.first(where: { $0.id == providerId }) {
            return provider.type == .google ? "g.circle.fill" : "o.circle.fill"
        }
        if let provider = appState.providers.first(where: { $0.name == appState.modelConfig.provider }) {
            return provider.type == .google ? "g.circle.fill" : "o.circle.fill"
        }
        return "o.circle.fill"
    }
    
    private func selectModel(_ model: String, from provider: ProviderConfig) {
        appState.modelConfig.modelName = model
        appState.modelConfig.provider = provider.name
        appState.modelConfig.providerId = provider.id
        
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
    
    private func getActiveProviderCredentials() -> (providerType: String, apiKey: String, baseUrl: String?) {
        let providerConfig: ProviderConfig?
        if let providerId = appState.modelConfig.providerId {
            providerConfig = appState.providers.first(where: { $0.id == providerId })
        } else {
            providerConfig = appState.providers.first(where: { $0.name == appState.modelConfig.provider })
        }
        
        if let provider = providerConfig {
            return (providerType: provider.type.rawValue, apiKey: provider.apiKey, baseUrl: provider.endpointUrl)
        } else {
            let settings = StorageService.shared.loadSettings()
            let providerType = appState.modelConfig.provider
            let apiKey = settings.connectors[providerType] ?? ""
            let baseUrl = settings.connectors["\(providerType)_base"]
            return (providerType: providerType, apiKey: apiKey, baseUrl: baseUrl)
        }
    }
}
