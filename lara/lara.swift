//
//  lara.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

enum taboptions {
    case applying, tweaks, files, logs
}

let g_isunsupported: Bool = isunsupported()
var weonadebugbuild_pjbweouttahereexclamationmark: Bool = false

@main
struct lara: App {
    @StateObject private var mgr = laramgr.shared
    @StateObject private var iconthememgr = IconThemeManager.shared
    @Environment(\.scenePhase) var scenephase
    @AppStorage("selectedMethod") private var selectedMethod: method = .hybrid
    @AppStorage("keepAlive") private var keepalive: Bool = false
    @AppStorage("showFMInTabs") private var showfmintabs: Bool = true
    @AppStorage("logsdisplaymode") private var logsdisplaymode: logsdisplaymode = .toolbar
    @State private var selectedtab: taboptions = .applying
    
    init() {
        #if DEBUG
        weonadebugbuild_pjbweouttahereexclamationmark = true
        #endif
        
        // fix file picker
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        method_exchangeImplementations(origMethod, fixMethod)
        
        if keepalive {
            toggleka()
        }
        
        globallogger.capture()
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedtab) {
                ContentView()
                    .tabItem {
                        Image(systemName: "wrench.and.screwdriver.fill")
                    }
                    .tag(taboptions.applying)
                
                // this has gotta fucking go
                TweaksView(mgr: mgr)
                    .tabItem {
                        Image(systemName: "ant.fill")
                    }
                    .tag(taboptions.tweaks)
                
                
                // i'm gonna strangle you root (the weight of your actions will crush you)
                if showfmintabs {
                    SantanderView(startPath: "/")
                        .tabItem {
                            Image(systemName: "folder.fill")
                        }
                        .tag(taboptions.files)
                }
                
                // this too
                if logsdisplaymode == .tabs {
                    LogsView(logger: globallogger)
                        .tabItem {
                            Image(systemName: "terminal")
                        }
                        .tag(taboptions.logs)
                }
            }
            .environmentObject(mgr)
            .overlay {
                if mgr.showrespring {
                    respringview()
                        .brightness(-1.0)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: Binding(
                get: { logsdisplaymode == .toolbar && mgr.showLogs },
                set: { mgr.showLogs = $0 }
            )) {
                LogsView(logger: globallogger)
            }
            .sheet(isPresented: $iconthememgr.showFixupSheet) {
                IconThemeFixupView()
            }
            .onAppear {
                if !isunsupported() {
                    init_offsets()
                    offsets_init()
                    iconthememgr.startPendingFixupIfPossible()
                    // beautiful name root
                    // thanks
                    mgr.hasOffsets = emergencyfixfunctiontobereplacedlateronquestionmark()
                } else {
                    Alertinator.shared.alert(title: "This device is not supported!", body: "We apologize, but this device is currently not supported by Lara. Possible reasons: \n- You are on an unsupported iOS version (Supported: iOS 16.0 - iOS 18.7.1, iOS 26.0 - iOS 26.0.1) \n- Your device has MIE (A19+ or M5+) \n- A debugger is attached.", actionLabel: "Exit App", action: { exitinator() })
                }
            }
            .onChange(of: scenephase, perform: handleScenePhase)
            .onChange(of: mgr.sbxready) { ready in
                if ready {
                    iconthememgr.startPendingFixupIfPossible()
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "lara" else { return }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let route = host.isEmpty ? path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) : host

        var callbackURL: URL? = nil
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {
            if let callbackParam = items.first(where: { $0.name == "callback" || $0.name == "x-success" })?.value,
               let target = URL(string: callbackParam) {
                callbackURL = target
            }
        }

        switch route {
        case "bypass-3-apps", "3appbypass", "bypass", "auto-bypass":
            Haptic.shared.play(.medium)
            globallogger.log("[Shortcuts] Received deep link to bypass 3 app limit")
            
            mgr.runAuto3AppBypass { success, count, message in
                DispatchQueue.main.async {
                    if success {
                        Haptic.shared.notify(.success)
                        globallogger.log("[Shortcuts] 3 App Bypass successful: \(count) apps")
                    } else {
                        Haptic.shared.notify(.error)
                        globallogger.log("[Shortcuts] 3 App Bypass failed: \(message)")
                    }
                    
                    if let callback = callbackURL {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            UIApplication.shared.open(callback, options: [:], completionHandler: nil)
                        }
                    } else {
                        if !success {
                            Alertinator.shared.alert(title: "Bypass Failed", body: message)
                        }
                    }
                }
            }

        case "respring":
            globallogger.log("[Shortcuts] Received deep link to respring")
            mgr.respring()

        default:
            globallogger.log("[Shortcuts] Unrecognized route: \(route)")
        }
    }
    
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            handlebg()
            globallogger.stopcapture()

        case .active:
            globallogger.capture()
            iconthememgr.startPendingFixupIfPossible()

        @unknown default:
            break
        }
    }

    private func handlebg() {
        guard mgr.rcready else { return }
        let keepSpringBoardRemoteCallAlive = UserDefaults.standard.bool(forKey: "keepSpringBoardRemoteCallAliveIOS16")
        if isIOS16() && keepSpringBoardRemoteCallAlive {
            return
        }

        var bgTask: UIBackgroundTaskIdentifier = .invalid

        bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemoteCallCleanup") {
            endbgtask(&bgTask)
        }

        mgr.rcdestroy {
            self.endbgtask(&bgTask)
        }
    }

    private func endbgtask(_ task: inout UIBackgroundTaskIdentifier) {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}

// file picker fixes
extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

// make strings compatiable with errors
extension String: @retroactive Error {}
