import SwiftUI
import Network
import Carbon

struct ContentView: View {
    @StateObject private var server = GameControllerServer()
    @State private var receivedButtons: [String] = []
    @State private var keyMappings: [String: String] = [
        "L1": "W", "L2": "A", "L3": "S", "L4": "D",           // WASD movement
        "R1": "↑", "R2": "↓", "R3": "←", "R4": "→"    // Action keys
    ]
    @State private var hasAccessibilityPermission = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Game Controller Receiver (UDP)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Accessibility permission status
            HStack {
                Circle()
                    .fill(hasAccessibilityPermission ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(hasAccessibilityPermission ? "Accessibility Enabled" : "Accessibility Required")
                Spacer()
                if !hasAccessibilityPermission {
                    Button("Grant Permission") {
                        openAccessibilitySettings()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .font(.caption)
                }
            }
            .padding()
            .background(hasAccessibilityPermission ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(8)
            
            // Server status
            HStack {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(server.isRunning ? "UDP Server Running" : "UDP Server Stopped")
                Spacer()
                Text("Port: 12345")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Connected clients and stats
            HStack {
                Text("Active Clients: \(server.activeClients)")
                    .foregroundColor(.secondary)
                Spacer()
                Text("Messages/sec: \(server.messagesPerSecond)")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            // Control buttons
            HStack(spacing: 20) {
                Button(server.isRunning ? "Stop Server" : "Start Server") {
                    if server.isRunning {
                        server.stopServer()
                    } else {
                        server.startServer()
                    }
                }
                .padding()
                .background(server.isRunning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Clear Log") {
                    receivedButtons.removeAll()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Key mappings
            GroupBox("Key Mappings") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(Array(keyMappings.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .fontWeight(.semibold)
                            Text("→")
                                .foregroundColor(.secondary)
                            TextField("Key", text: Binding(
                                get: { keyMappings[key] ?? "" },
                                set: { keyMappings[key] = $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 50)
                        }
                    }
                }
                .padding()
            }
            
            // Recent button presses log
            GroupBox("Recent Button Presses") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(receivedButtons.enumerated().reversed()), id: \.offset) { index, button in
                            HStack {
                                Text(button)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("→ \(keyMappings[button] ?? "Not mapped")")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // Instructions
            Text("Instructions:")
                .font(.headline)
            VStack(alignment: .leading, spacing: 5) {
                Text("1. Start the UDP server on your Mac")
                Text("2. Your Mac's IP addresses:")
                ForEach(getLocalIPAddresses(), id: \.self) { ip in
                    Text("   • \(ip)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
                Text("3. Update the iOS app with your Mac's IP address")
                Text("4. Connect from your iPhone")
                Text("5. Customize key mappings above as needed")
                Text("6. Single tap for one key press, long press for continuous")
                Text("Note: UDP provides lower latency but no delivery guarantee")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            checkAccessibilityPermission()
        }
        .onReceive(server.$lastReceivedButton) { button in
            if !button.isEmpty && button != "HEARTBEAT" {
                receivedButtons.append(button)
                if receivedButtons.count > 50 {
                    receivedButtons.removeFirst()
                }
                
                // Simulate key press
                if let mappedKey = keyMappings[button] {
                    server.simulateKeyPress(mappedKey)
                }
            }
        }
    }
    
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        
        // Check periodically in case user grants permission
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let newStatus = AXIsProcessTrusted()
            if newStatus != hasAccessibilityPermission {
                DispatchQueue.main.async {
                    hasAccessibilityPermission = newStatus
                    if newStatus {
                        print("✅ Accessibility permission granted!")
                    }
                }
            }
        }
    }
    
    private func openAccessibilitySettings() {
        let prefURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: prefURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func getLocalIPAddresses() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface!.ifa_name)
                    if name == "en0" || name == "en1" || name.hasPrefix("en") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t(interface!.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        let address = String(cString: hostname)
                        if !address.isEmpty && address != "127.0.0.1" && !address.hasPrefix("::") {
                            addresses.append("\(address) (\(name))")
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return addresses
    }
}

class GameControllerServer: ObservableObject {
    @Published var isRunning = false
    @Published var activeClients = 0
    @Published var lastReceivedButton = ""
    @Published var messagesPerSecond = 0
    
    private var listener: NWListener?
    private var keySimulationQueue = DispatchQueue(label: "keySimulation", qos: .userInitiated)
    
    // Message rate tracking
    private var messageCount = 0
    private var messageTimer: Timer?
    
    // Client tracking for UDP
    private var clientAddresses: Set<String> = []
    private var clientLastSeen: [String: Date] = [:]
    private var clientCleanupTimer: Timer?
    
    init() {
        // Start message rate tracking
        messageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.messagesPerSecond = self?.messageCount ?? 0
                self?.messageCount = 0
            }
        }
        
        // Start client cleanup timer
        clientCleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.cleanupInactiveClients()
        }
    }
    
    deinit {
        messageTimer?.invalidate()
        clientCleanupTimer?.invalidate()
    }
    
    func startServer() {
        // Stop any existing server first
        if listener != nil {
            stopServer()
        }
        
        guard let port = NWEndpoint.Port(rawValue: 12345) else {
            print("Invalid port number")
            return
        }
        
        do {
            listener = try NWListener(using: .udp, on: port)
        } catch {
            print("Failed to create UDP listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("✅ UDP Server successfully started on port 12345")
                case .failed(let error):
                    print("❌ UDP Server failed to start: \(error)")
                    self?.isRunning = false
                case .cancelled:
                    print("🛑 UDP Server cancelled")
                    self?.isRunning = false
                default:
                    print("UDP Server state: \(state)")
                }
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            print("📡 New UDP connection established")
            self?.handleNewConnection(connection)
        }
        
        listener?.start(queue: .global())
    }
    
    func stopServer() {
        print("🛑 Stopping UDP server...")
        listener?.cancel()
        listener = nil
        
        clientAddresses.removeAll()
        clientLastSeen.removeAll()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.activeClients = 0
            print("✅ UDP Server stopped successfully")
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("🔗 Handling new UDP connection...")
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ UDP Connection ready")
            case .cancelled:
                print("👋 UDP Connection cancelled")
            case .failed(let error):
                print("❌ UDP Connection failed: \(error)")
            default:
                print("UDP Connection state: \(state)")
            }
        }
        
        connection.start(queue: .global())
        receiveMessage(from: connection)
    }
    
    private func receiveMessage(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                // Get client address from the connection's remote endpoint
                var clientAddress = "unknown"
//                if let remoteEndpoint = connection.endpoint {
                clientAddress = "\(connection.endpoint)"
//                }
                
                // Update client tracking
                self?.updateClientActivity(clientAddress)
                
                DispatchQueue.main.async {
                    self?.lastReceivedButton = message
                    if message != "HEARTBEAT" {
                        self?.messageCount += 1
                    }
                }
                
                print("📨 Received from \(clientAddress): \(message)")
            }
            
            if let error = error {
                print("❌ UDP Receive error: \(error)")
            }
            
            // Continue receiving messages
            self?.receiveMessage(from: connection)
        }
    }
    
    private func updateClientActivity(_ clientAddress: String) {
        let now = Date()
        clientLastSeen[clientAddress] = now
        
        if !clientAddresses.contains(clientAddress) {
            clientAddresses.insert(clientAddress)
            print("📱 New client connected: \(clientAddress)")
        }
        
        DispatchQueue.main.async {
            self.activeClients = self.clientAddresses.count
        }
    }
    
    private func cleanupInactiveClients() {
        let now = Date()
        let timeout: TimeInterval = 10.0 // 10 seconds timeout
        
        var inactiveClients: [String] = []
        
        for (clientAddress, lastSeen) in clientLastSeen {
            if now.timeIntervalSince(lastSeen) > timeout {
                inactiveClients.append(clientAddress)
            }
        }
        
        for clientAddress in inactiveClients {
            clientAddresses.remove(clientAddress)
            clientLastSeen.removeValue(forKey: clientAddress)
            print("⏰ Client timeout: \(clientAddress)")
        }
        
        if !inactiveClients.isEmpty {
            DispatchQueue.main.async {
                self.activeClients = self.clientAddresses.count
            }
        }
    }
    
    func simulateKeyPress(_ key: String) {
        keySimulationQueue.async {
            guard let keyCode = self.getKeyCode(for: key) else {
                return
            }
            
            // Check if we have accessibility permissions
            let trusted = AXIsProcessTrusted()
            if !trusted {
                return
            }
            
            let source = CGEventSource(stateID: .hidSystemState)
            
            // Key down
            if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                keyDownEvent.post(tap: .cghidEventTap)
            }
            
            // Very small delay for key press simulation
            usleep(1000) // 1ms delay - optimized for UDP
            
            // Key up
            if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                keyUpEvent.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func getKeyCode(for key: String) -> CGKeyCode? {
        switch key.uppercased() {
        case "A": return 0x00
        case "S": return 0x01
        case "D": return 0x02
        case "F": return 0x03
        case "H": return 0x04
        case "G": return 0x05
        case "Z": return 0x06
        case "X": return 0x07
        case "C": return 0x08
        case "V": return 0x09
        case "B": return 0x0B
        case "Q": return 0x0C
        case "W": return 0x0D
        case "E": return 0x0E
        case "R": return 0x0F
        case "Y": return 0x10
        case "T": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "O": return 0x1F
        case "U": return 0x20
        case "[": return 0x21
        case "I": return 0x22
        case "P": return 0x23
        case "L": return 0x25
        case "J": return 0x26
        case "'": return 0x27
        case "K": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "N": return 0x2D
        case "M": return 0x2E
        case ".": return 0x2F
        case "`": return 0x32
        case " ", "SPACE": return 0x31
        case "SHIFT": return 0x38
        case "CTRL": return 0x3B
        case "ALT", "OPTION": return 0x3A
        case "CMD", "COMMAND": return 0x37
        case "TAB": return 0x30
        case "ENTER", "RETURN": return 0x24
        case "ESC", "ESCAPE": return 0x35
        case "BACKSPACE": return 0x33
        case "↑": return 0x7E
        case "↓": return 0x7D
        case "←": return 0x7B
        case "→": return 0x7C
        default: return nil
        }
    }
}

#Preview {
    ContentView()
}
