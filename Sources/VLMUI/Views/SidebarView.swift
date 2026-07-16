import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    // UI state for rename dialog and delete confirmations
    @State private var folderToDelete: Folder? = nil
    @State private var chatToDelete: ChatThread? = nil
    
    @State private var showFolderDeleteAlert = false
    @State private var showChatDeleteAlert = false
    
    @State private var showRenameDialog = false
    @State private var renamingFolder: Folder? = nil
    @State private var renamingChat: ChatThread? = nil
    @State private var renameText = ""
    
    @State private var showNewFolderDialog = false
    @State private var parentFolderForNewFolder: Folder? = nil // nil means root
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Create Buttons
            HStack {
                Text("VLM Workspace")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Add Folder
                Button(action: {
                    parentFolderForNewFolder = nil
                    newFolderName = ""
                    showNewFolderDialog = true
                }) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("New Folder")
                
                // Add Chat at Root
                Button(action: {
                    createNewChat(in: nil)
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("New Chat")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Folder & Chat Tree
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Root-level Chats
                    ForEach(appState.folders.flatMap { $0.chats }) { chat in
                        // Handled if we want to display all root level chats.
                        // Instead, let's display folders and their contents.
                    }
                    
                    if appState.folders.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Spacer().frame(height: 40)
                            Text("No Folders Created")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Click the folder icon above to create one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(appState.folders) { folder in
                            FolderNodeView(
                                folder: folder,
                                depth: 0,
                                onAddSubfolder: { parent in
                                    parentFolderForNewFolder = parent
                                    newFolderName = ""
                                    showNewFolderDialog = true
                                },
                                onAddChat: { parent in
                                    createNewChat(in: parent)
                                },
                                onRenameFolder: { folder in
                                    renamingFolder = folder
                                    renameText = folder.name
                                    showRenameDialog = true
                                },
                                onDeleteFolder: { folder in
                                    folderToDelete = folder
                                    showFolderDeleteAlert = true
                                },
                                onRenameChat: { chat in
                                    renamingChat = chat
                                    renameText = chat.title
                                    showRenameDialog = true
                                },
                                onDeleteChat: { chat in
                                    chatToDelete = chat
                                    showChatDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            Divider()
            
            // Settings and Status Panel
            HStack {
                Button(action: {
                    appState.isSettingsPresented = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.medium)
                        Text("Settings")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
            .padding(12)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
        
        // MARK: - Alerts and Sheets
        
        // Deleting Folder Confirmation
        .alert("Delete Folder", isPresented: $showFolderDeleteAlert, actions: {
            Button("Delete Everything Inside", role: .destructive) {
                if let folder = folderToDelete {
                    deleteFolder(folder)
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Are you sure you want to delete '\(folderToDelete?.name ?? "")'? This will permanently delete all subfolders and chat threads inside it.")
        })
        
        // Deleting Chat Confirmation
        .alert("Delete Chat", isPresented: $showChatDeleteAlert, actions: {
            Button("Delete Chat Thread", role: .destructive) {
                if let chat = chatToDelete {
                    deleteChat(chat)
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Are you sure you want to permanently delete '\(chatToDelete?.title ?? "")'?")
        })
        
        // Rename Dialog
        .sheet(isPresented: $showRenameDialog) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rename Item")
                    .font(.headline)
                
                TextField("Enter new name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performRename()
                    }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showRenameDialog = false
                    }
                    Button("Rename") {
                        performRename()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 300)
        }
        
        // New Folder Dialog
        .sheet(isPresented: $showNewFolderDialog) {
            VStack(alignment: .leading, spacing: 16) {
                Text(parentFolderForNewFolder == nil ? "New Root Folder" : "New Subfolder")
                    .font(.headline)
                
                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performCreateFolder()
                    }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showNewFolderDialog = false
                    }
                    Button("Create") {
                        performCreateFolder()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 300)
        }
    }
    
    // MARK: - Actions
    
    private func createNewChat(in folder: Folder?) {
        let newChat = ChatThread(title: "New Chat Thread")
        newChat.messages = []
        
        if let folder = folder {
            folder.chats.append(newChat)
        } else {
            // If no folder, create a default "General" folder to hold it or place in first folder
            if appState.folders.isEmpty {
                let generalFolder = Folder(name: "General", chats: [newChat])
                appState.folders.append(generalFolder)
            } else {
                appState.folders[0].chats.append(newChat)
            }
        }
        
        appState.selectedThreadId = newChat.id
        saveWorkspaceState()
    }
    
    private func performRename() {
        if let folder = renamingFolder {
            folder.name = renameText
            renamingFolder = nil
        } else if let chat = renamingChat {
            chat.title = renameText
            renamingChat = nil
        }
        showRenameDialog = false
        saveWorkspaceState()
    }
    
    private func performCreateFolder() {
        guard !newFolderName.isEmpty else { return }
        let newFolder = Folder(name: newFolderName)
        
        if let parent = parentFolderForNewFolder {
            parent.subfolders.append(newFolder)
        } else {
            appState.folders.append(newFolder)
        }
        
        showNewFolderDialog = false
        saveWorkspaceState()
    }
    
    private func deleteFolder(_ folder: Folder) {
        func removeRecursively(from folders: inout [Folder]) -> Bool {
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders.remove(at: index)
                return true
            }
            for index in folders.indices {
                if removeRecursively(from: &folders[index].subfolders) {
                    return true
                }
            }
            return false
        }
        
        _ = removeRecursively(from: &appState.folders)
        folderToDelete = nil
        saveWorkspaceState()
    }
    
    private func deleteChat(_ chat: ChatThread) {
        func removeChat(from folders: inout [Folder]) -> Bool {
            for index in folders.indices {
                if let chatIndex = folders[index].chats.firstIndex(where: { $0.id == chat.id }) {
                    folders[index].chats.remove(at: chatIndex)
                    if appState.selectedThreadId == chat.id {
                        appState.selectedThreadId = nil
                    }
                    return true
                }
                if removeChat(from: &folders[index].subfolders) {
                    return true
                }
            }
            return false
        }
        
        _ = removeChat(from: &appState.folders)
        chatToDelete = nil
        saveWorkspaceState()
    }
    
    private func saveWorkspaceState() {
        appState.saveWorkspace()
    }
}

// MARK: - Folder Node View (Recursive Tree View)

struct FolderNodeView: View {
    @ObservedObject var folder: Folder
    var depth: CGFloat
    
    var onAddSubfolder: (Folder) -> Void
    var onAddChat: (Folder) -> Void
    var onRenameFolder: (Folder) -> Void
    var onDeleteFolder: (Folder) -> Void
    
    var onRenameChat: (ChatThread) -> Void
    var onDeleteChat: (ChatThread) -> Void
    
    @State private var isExpanded = true
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder Row
            HStack(spacing: 6) {
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
                
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundColor(.accentColor)
                
                Text(folder.name)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.leading, depth * 12)
            .contentShape(Rectangle())
            .contextMenu {
                Button("New Subfolder") { onAddSubfolder(folder) }
                Button("New Chat") { onAddChat(folder) }
                Divider()
                Button("Rename Folder...") { onRenameFolder(folder) }
                Button("Delete Folder", role: .destructive) { onDeleteFolder(folder) }
            }
            
            // Children (Subfolders & Chats)
            if isExpanded {
                // Chats inside this folder
                ForEach(folder.chats) { chat in
                    ChatRowView(
                        chat: chat,
                        isSelected: appState.selectedThreadId == chat.id,
                        depth: depth + 1,
                        onRename: { onRenameChat(chat) },
                        onDelete: { onDeleteChat(chat) }
                    )
                    .onDrag {
                        NSItemProvider(object: chat.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: ChatDropDelegate(targetFolder: folder, chat: chat, appState: appState))
                }
                
                // Subfolders
                ForEach(folder.subfolders) { subfolder in
                    FolderNodeView(
                        folder: subfolder,
                        depth: depth + 1,
                        onAddSubfolder: onAddSubfolder,
                        onAddChat: onAddChat,
                        onRenameFolder: onRenameFolder,
                        onDeleteFolder: onDeleteFolder,
                        onRenameChat: onRenameChat,
                        onDeleteChat: onDeleteChat
                    )
                    .onDrop(of: [UTType.text], delegate: FolderDropDelegate(targetFolder: subfolder, appState: appState))
                }
            }
        }
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    @ObservedObject var chat: ChatThread
    var isSelected: Bool
    var depth: CGFloat
    
    var onRename: () -> Void
    var onDelete: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(isSelected ? .white : .secondary)
            
            Text(chat.title)
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .padding(.leading, depth * 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovering ? Color.primary.opacity(0.06) : Color.clear))
        )
        .onHover { hover in
            isHovering = hover
        }
        .onTapGesture {
            appState.selectedThreadId = chat.id
        }
        .contextMenu {
            Button("Rename Chat...") { onRename() }
            Button("Delete Chat", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Drag and Drop Delegates

struct ChatDropDelegate: DropDelegate {
    let targetFolder: Folder
    let chat: ChatThread
    let appState: AppState
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [UTType.text]).first else { return false }
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
            guard let data = data as? Data, let idString = String(data: data, encoding: .utf8), let sourceId = UUID(uuidString: idString) else { return }
            
            DispatchQueue.main.async {
                self.moveChat(withId: sourceId, to: targetFolder)
            }
        }
        return true
    }
    
    private func moveChat(withId id: UUID, to folder: Folder) {
        var foundChat: ChatThread? = nil
        
        // Helper to remove chat from current position
        func removeChat(from folders: inout [Folder]) -> Bool {
            for index in folders.indices {
                if let chatIndex = folders[index].chats.firstIndex(where: { $0.id == id }) {
                    foundChat = folders[index].chats.remove(at: chatIndex)
                    return true
                }
                if removeChat(from: &folders[index].subfolders) {
                    return true
                }
            }
            return false
        }
        
        _ = removeChat(from: &appState.folders)
        
        if let chatToMove = foundChat {
            folder.chats.append(chatToMove)
            appState.saveWorkspace()
        }
    }
}

struct FolderDropDelegate: DropDelegate {
    let targetFolder: Folder
    let appState: AppState
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [UTType.text]).first else { return false }
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
            guard let data = data as? Data, let idString = String(data: data, encoding: .utf8), let sourceId = UUID(uuidString: idString) else { return }
            
            DispatchQueue.main.async {
                // Determine if we are moving a chat or a folder (we check chats first)
                if self.findAndMoveChat(withId: sourceId, to: self.targetFolder) {
                    return
                }
                self.findAndMoveFolder(withId: sourceId, to: self.targetFolder)
            }
        }
        return true
    }
    
    private func findAndMoveChat(withId id: UUID, to folder: Folder) -> Bool {
        var foundChat: ChatThread? = nil
        
        func removeChat(from folders: inout [Folder]) -> Bool {
            for index in folders.indices {
                if let chatIndex = folders[index].chats.firstIndex(where: { $0.id == id }) {
                    foundChat = folders[index].chats.remove(at: chatIndex)
                    return true
                }
                if removeChat(from: &folders[index].subfolders) {
                    return true
                }
            }
            return false
        }
        
        _ = removeChat(from: &appState.folders)
        
        if let chatToMove = foundChat {
            folder.chats.append(chatToMove)
            appState.saveWorkspace()
            return true
        }
        return false
    }
    
    private func findAndMoveFolder(withId id: UUID, to parentFolder: Folder) {
        if id == parentFolder.id { return } // Cannot move folder into itself
        
        var foundFolder: Folder? = nil
        
        func removeFolder(from folders: inout [Folder]) -> Bool {
            if let index = folders.firstIndex(where: { $0.id == id }) {
                foundFolder = folders.remove(at: index)
                return true
            }
            for index in folders.indices {
                if removeFolder(from: &folders[index].subfolders) {
                    return true
                }
            }
            return false
        }
        
        _ = removeFolder(from: &appState.folders)
        
        if let folderToMove = foundFolder {
            parentFolder.subfolders.append(folderToMove)
            appState.saveWorkspace()
        }
    }
}
