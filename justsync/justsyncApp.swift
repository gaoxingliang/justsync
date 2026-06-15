import SwiftUI
import AVFoundation
import BackgroundTasks

@main
struct JustSyncApp: App {
    @StateObject private var serverManager = WebServerManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("App became active")
        case .inactive:
            print("App became inactive")
        case .background:
            print("App moved to background - server will continue running")
            keepAliveInBackground()
        @unknown default:
            break
        }
    }
    
    private func keepAliveInBackground() {
        DispatchQueue.global(qos: .background).async {
            Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
                print("Background keepalive tick")
            }
            RunLoop.current.run()
        }
    }
}
