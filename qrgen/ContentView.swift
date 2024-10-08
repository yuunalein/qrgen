import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        RegularView()
        #else
        if UIScreen.main.traitCollection.horizontalSizeClass == .compact {
            CompactView()
        } else {
            RegularView()
        }
        #endif
    }
}

private struct RegularView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var mode: Mode = .new

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    if let name = item.name {
                        Text(name)
                            .onTapGesture {
                                mode = .edit(item)
                            }
                    } else {
                        Text("Unnamed")
                            .onTapGesture {
                                mode = .edit(item)
                            }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Saved")
        } detail: {
            CreateView(mode: $mode)
                .onChange(of: mode) {
                    print(mode)
                }
        }
    }

    private func addItem() {
        withAnimation {
            mode = .new
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

private struct CompactView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var path: NavigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(items) { item in
                    NavigationLink(value: Mode.edit(item)) {
                        if let name = item.name {
                            Text(name)
                        } else {
                            Text("Unnamed")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                #if !os(macOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: Mode.self) {value in
                CreateView(mode: value)
            }
        }
        .onAppear {
            addItem()
        }
    }

    private func addItem() {
        withAnimation {
            path.append(Mode.new)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true, isAutosaveEnabled: true)
}
