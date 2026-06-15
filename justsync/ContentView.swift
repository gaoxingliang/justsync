import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serverManager: WebServerManager
    @StateObject private var photoManager = PhotoLibraryManager()
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                GroupBox(label: Label("服务器状态", systemImage: "server.rack")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("状态:")
                                .fontWeight(.medium)
                            Spacer()
                            StatusIndicator(isRunning: serverManager.isRunning)
                        }
                        
                        if serverManager.isRunning {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("访问地址:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(serverManager.serverAddresses, id: \.self) { address in
                                    HStack {
                                        Text(address)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.blue)
                                        
                                        Button(action: {
                                            UIPasteboard.general.string = address
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                GroupBox(label: Label("相册信息", systemImage: "photo.on.rectangle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(title: "照片数量", value: "\(photoManager.photoCount)")
                        InfoRow(title: "视频数量", value: "\(photoManager.videoCount)")
                        InfoRow(title: "总计", value: "\(photoManager.totalCount)")
                    }
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if serverManager.isRunning {
                        Button(action: {
                            serverManager.stopServer()
                        }) {
                            Label("停止服务器", systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            startServerManually()
                        }) {
                            Label("启动服务器", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("JustSync")
            .alert("需要相册访问权限", isPresented: $showingPermissionAlert) {
                Button("前往设置", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("JustSync 需要访问您的照片库才能共享照片。请在设置中允许访问。")
            }
            .onAppear {
                autoStartServer()
            }
        }
    }
    
    private func autoStartServer() {
        Task {
            await photoManager.requestPermission()
            if photoManager.hasPermission {
                await photoManager.loadPhotos()
                serverManager.startServer(photoManager: photoManager)
            }
        }
    }
    
    private func startServerManually() {
        Task {
            await photoManager.requestPermission()
            if photoManager.hasPermission {
                await photoManager.loadPhotos()
                serverManager.startServer(photoManager: photoManager)
            } else {
                showingPermissionAlert = true
            }
        }
    }
}

struct StatusIndicator: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(isRunning ? "运行中" : "已停止")
                .font(.subheadline)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
