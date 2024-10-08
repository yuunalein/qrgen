import SwiftUI

enum Mode: Equatable, Hashable {
    case edit(Item)
    case new

    func item() -> Item {
        switch self {
        case .edit(let item):
            return item
        case .new:
            return Item(timestamp: Date())
        }
    }
}

enum NetworkType: CaseIterable, Identifiable, Codable, Hashable {
    case none
    case wep
    case wpa

    var id: Self { self }

    func toString() -> String {
        switch self {
        case .none:
            "nopass"
        case .wep:
            "WEP"
        case .wpa:
            "WPA"
        }
    }

    func readable() -> String {
        switch self {
        case .none:
            "None"
        case .wep:
            "WEP"
        case .wpa:
            "WPA"
        }
    }
}

private enum SimpleQRMode: CaseIterable, Identifiable {
    var id: Self { self }

    case plain
    case url
    case wlan

    static func from(mode: QRMode) -> Self {
        switch mode {
        case .plain:
            .plain
        case .url:
            .url
        case .wlan:
            .wlan
        }
    }

    func toString() -> String {
        switch self {
        case .plain:
            "Plain"
        case .url:
            "URL"
        case .wlan:
            "WiFi"
        }
    }
}

enum QRMode: Codable, Hashable {
    case plain(String)
    case url(String)
    case wlan(String, String, NetworkType, Bool)

    static fileprivate func from(mode: SimpleQRMode) -> Self {
        switch mode {
        case .plain:
            .plain("")
        case .url:
            .url("")
        case .wlan:
            .wlan("", "", NetworkType.wpa, false)
        }
    }

    func toQRString() -> String {
        switch self {
        case .url(let value), .plain(let value):
            return value
        case .wlan(let ssid, let password, let netType, let isHidden):
            let hidden = if isHidden { ";H:true" } else { "" }
            let pass = if netType != .none { ";P:\(password)" } else { "" }

            return "WIFI:S:\(ssid);T:\(netType.toString())\(pass)\(hidden);;"
        }
    }
}

struct CreateView: View {
    @Environment(\.modelContext) private var modelContext
    #if !os(macOS)
    @Environment(\.dismiss) private var dismiss
    #endif
    var modeBinding: Binding<Mode>?
    @State var mode: Mode
    @State var item: Item
    @State var showSaveAlert: Bool = false
    @State var name: String = ""
    @State private var qrMode: SimpleQRMode

    init(mode: Binding<Mode>) {
        self.mode = mode.wrappedValue
        self.modeBinding = mode
        let item = mode.wrappedValue.item()
        self.item = item
        self.qrMode = SimpleQRMode.from(mode: item.qrContent)
    }

    init(mode: Mode) {
        self.mode = mode
        self.modeBinding = nil
        let item = mode.item()
        self.item = item
        self.qrMode = SimpleQRMode.from(mode: item.qrContent)
    }

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: 216, height: 216)
                    .foregroundStyle(.white)
                #if canImport(UIKit)
                Image(uiImage: generateQRCode(from: item.qrContent.toQRString()))
                #elseif canImport(AppKit)
                Image(nsImage: generateQRCode(from: item.qrContent.toQRString()))
                #endif
            }
            .padding(12)
            Form {
                Picker("Type", selection: $qrMode) {
                    ForEach(SimpleQRMode.allCases) {option in
                        Text(option.toString()).tag(option)
                    }
                    .onChange(of: qrMode, initial: true) {_, value in
                        item.qrContent = QRMode.from(mode: value)
                    }
                }
                Section {
                    switch item.qrContent {
                    case .plain, .url:
                        PlainInput(mode: $item.qrContent)
                    case .wlan:
                        WLANInput(mode: $item.qrContent)
                    }
                }
                if mode == .new {
                    Section {
                        Button {
                            showSaveAlert = true
                        } label: {
                            Text("Save")
                                .frame(maxWidth: .infinity)
                                #if os(iOS)
                                .foregroundStyle(.white)
                                #endif
                        }
                        #if os(macOS)
                        .buttonStyle(.borderedProminent)
                        #endif
                    }
                    #if os(iOS)
                    .listRowBackground(Color.accentColor)
                    #endif
                } else {
                    Section {
                        Button {
                            showSaveAlert = true
                        } label: {
                            Text("Rename")
                        }
                        Button {
                            modelContext.delete(item)
                            #if !os(macOS)
                            dismiss()
                            #else
                            modeBinding?.wrappedValue = .new
                            #endif
                        } label: {
                            Text("Delete")
                                #if os(iOS)
                                .foregroundStyle(.red)
                                #endif
                        }
                    }
                }
            }
            #if os(macOS)
            .padding(8)
            #endif
            .onChange(of: modeBinding?.wrappedValue, initial: true) {_, new in
                if let value = new {
                    item = value.item()
                    mode = value
                }
            }
            .alert("Save this QR Code", isPresented: $showSaveAlert) {
                TextField("Name", text: $name)

                Button("Cancel", role: .cancel, action: {
                    name = ""
                })
                Button("Save", action: {
                    item.name = name
                    name = ""
                    modelContext.insert(item)

                    if mode == .new {
                        mode = .edit(item)
                    }
                })
            } message: {
                Text("Please name this QR Code to save it.")
            }
        }
    }
}

private struct PlainInput: View {
    @Binding var mode: QRMode
    @State var text: String
    @State var hint: String

    init?(mode: Binding<QRMode>) {
        switch mode.wrappedValue {
        case .plain, .url:
            self._mode = mode
            self.text = PlainInput.getText(mode: mode.wrappedValue)
            self.hint = PlainInput.getHint(mode: mode.wrappedValue)
        default:
            return nil
        }
    }

    var body: some View {
        TextField("", text: $text, prompt: Text(hint))
            #if os(iOS)
            .autocapitalization(.none)
            #endif
            .autocorrectionDisabled(true)
            .onChange(of: text, {_, value in
                switch mode {
                case .url:
                    mode = .url(value)
                default:
                    mode = .plain(value)
                }
                hint = PlainInput.getHint(mode: mode)
            })
            .onChange(of: mode) {
                text = PlainInput.getText(mode: mode)
                hint = PlainInput.getHint(mode: mode)
            }
    }

    private static func getText(mode: QRMode) -> String {
        switch mode {
        case .url(let value), .plain(let value):
            value
        default:
            ""
        }
    }

    private static func getHint(mode: QRMode) -> String {
        switch mode {
        case .url:
            "https://..."
        default:
            "Text..."
        }
    }
}

private struct WLANInput: View {
    @Binding var mode: QRMode
    @State var ssid: String
    @State var password: String
    @State var netType: NetworkType
    @State var isHidden: Bool

    init?(mode: Binding<QRMode>) {
        if let states = States(mode: mode.wrappedValue) {
            self._mode = mode
            self.ssid = states.ssid
            self.password = states.password
            self.netType = states.netType
            self.isHidden = states.isHidden
        } else {
            return nil
        }
    }

    var body: some View {
        Section {
            Picker("Security Profile", selection: $netType) {
                ForEach(NetworkType.allCases) {option in
                    Text(option.readable()).tag(option)
                }
            }
            TextField("SSID", text: $ssid)
                #if os(iOS)
                .autocapitalization(.none)
                #endif
                .autocorrectionDisabled(true)
            if netType != .none {
                SecureField("Password", text: $password)
            }
            Toggle(isOn: $isHidden) {
                Text("Hidden Network")
            }
        }
        .onChange(of: ssid) { update() }
        .onChange(of: password) { update() }
        .onChange(of: netType) { update() }
        .onChange(of: isHidden) { update() }
        .onChange(of: mode) {
            if let states = States(mode: mode) {
                ssid = states.ssid
                password = states.password
                netType = states.netType
                isHidden = states.isHidden
            }
        }
    }

    private struct States {
        var ssid: String
        var password: String
        var netType: NetworkType
        var isHidden: Bool

        init?(mode: QRMode) {
            switch mode {
            case .wlan(let ssid, let password, let netType, let isHidden):
                self.ssid = ssid
                self.password = password
                self.netType = netType
                self.isHidden = isHidden
            default:
                return nil
            }
        }
    }

    func update() {
        mode = .wlan(ssid, password, netType, isHidden)
    }
}

#Preview {
    CreateView(mode: .new)
        .modelContainer(for: Item.self, inMemory: true, isAutosaveEnabled: true)
}
