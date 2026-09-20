//
//  ContentView.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var mgr: laramgr
    @ObservedObject private var logger = globallogger
    @AppStorage("selectedMethod") private var selectedmethod: method = .hybrid
    @AppStorage("logsdisplaymode") private var selectedlogsdisplaymode: logsdisplaymode = .toolbar
    @AppStorage("loggerNoBS") private var loggernobs: Bool = true
    
    @State private var showSettings: Bool = false
    @State private var dlingkcache: Bool = false
    @State private var copiedURLToast: Bool = false
    
    init() {
        globallogger.capture()
    }
    
    var body: some View {
        NavigationStack {
            List {
                AlertsSection
                KRWSection
                BypassSection
                RCSection
                ActionsSection
                DebugSection
                InlineLogsSection
            }
            .navigationTitle("lara")
            .toolbar {
                if selectedlogsdisplaymode == .toolbar {
                    Button(action: {
                        mgr.showLogs.toggle()
                    }) {
                        Image(systemName: "terminal")
                    }
                }
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gear")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    private var AlertsSection: some View {
        Section {
            if !mgr.hasOffsets {
                PlainAlert(title: "No offsets found!", icon: "exclamationmark.triangle.fill", text: "Kernelcache offsets are missing. Click \"Run Exploit\" and then fetch the offsets.")
            }
        }
    }
    
    private var KRWSection: some View {
        Section {
            LabeledContent(content: {
                if mgr.dsready {
                    Image(systemName: "checkmark.circle")
                } else if mgr.dsrunning {
                    HStack {
                        Text("\(Int(mgr.dsprogress * 100))%")
                        ProgressView()
                    }
                } else if mgr.dsattempted && mgr.dsfailed {
                    Image(systemName: "xmark.circle")
                }
            }) {
                Button("Run Exploit", action: {
                    offsets_init()
                    mgr.run()
                })
                .disabled(mgr.dsready || mgr.dsrunning || isdebugged())
            }
            
            if !mgr.hasOffsets {
                Button {
                    guard !dlingkcache else { return }
                    dlingkcache = true

                    DispatchQueue.global(qos: .userInitiated).async {
                        let fetched = fetchkcache()

                        if fetched {
                            let dlkc = dlkcache()
                            DispatchQueue.main.async {
                                mgr.hasOffsets = dlkc
                                dlingkcache = false
                            }
                            return
                        }

                        DispatchQueue.main.async {
                            mgr.hasOffsets = false
                            dlingkcache = false
                        }
                    }
                } label: {
                    if dlingkcache {
                        HStack {
                            Text("Fetching Kernelcache...")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Text("Fetch Kernelcache")
                    }
                }
                .disabled(dlingkcache || !mgr.dsready)
            } else {
                if selectedmethod == .hybrid {
                    LabeledContent(content: {
                        if mgr.vfsready && mgr.sbxready {
                            Image(systemName: "checkmark.circle")
                        } else if mgr.vfsrunning || mgr.sbxrunning {
                            HStack {
                                Text("Running...")
                                ProgressView()
                            }
                        } else if (mgr.vfsattempted && mgr.vfsfailed) || (mgr.sbxattempted && mgr.sbxfailed) {
                            Image(systemName: "xmark.circle")
                        }
                    }) {
                        Button("Initialize System", action: {
                            mgr.vfsinit()
                            mgr.sbxescape()
                        })
                        .disabled(!mgr.hasOffsets || !mgr.dsready || mgr.vfsrunning || mgr.sbxrunning || (mgr.vfsready && mgr.sbxready))
                    }
                }
                
                // initalize vfs
                if selectedmethod == .vfs {
                    LabeledContent(content: {
                        if mgr.vfsready {
                            Image(systemName: "checkmark.circle")
                        } else if mgr.vfsrunning {
                            HStack {
                                Text("\(Int(mgr.dsprogress * 100))%")
                                ProgressView()
                            }
                        } else if mgr.vfsattempted && mgr.vfsfailed {
                            Image(systemName: "xmark.circle")
                        }
                    }) {
                        Button("Initialize VFS", action: {
                            mgr.vfsinit()
                        })
                        .disabled(!mgr.dsready || mgr.vfsready || mgr.vfsrunning || isdebugged())
                    }
                }
                
                // escape sandbox
                if selectedmethod == .sbx {
                    LabeledContent(content: {
                        if mgr.sbxready {
                            Image(systemName: "checkmark.circle")
                        } else if mgr.sbxrunning {
                            HStack {
                                Text("Running...")
                                ProgressView()
                            }
                        } else if mgr.sbxattempted && mgr.sbxfailed {
                            Image(systemName: "xmark.circle")
                        }
                    }) {
                        Button("Escape Sandbox", action: {
                            mgr.sbxescape()
                        })
                        .disabled(!mgr.dsready || mgr.sbxready || mgr.sbxrunning || isdebugged())
                    }
                }
            }
        } header: {
            HeaderLabel(text: "Kernel Read Write", icon: "externaldrive")
        } footer: {
            if isdebugged() {
                Text("Not available while a debugger is attached.")
            }
        }
    }
    
    private var BypassSection: some View {
        Section(header: HeaderLabel(text: "3 App Bypass", icon: "square.stack.3d.up")) {
            Button(action: {
                guard !mgr.isAutoBypassing else { return }
                Haptic.shared.play(.medium)
                
                mgr.runAuto3AppBypass { success, count, message in
                    DispatchQueue.main.async {
                        if success {
                            Haptic.shared.notify(.success)
                            Alertinator.shared.alert(
                                title: "3 App Bypass",
                                body: "Successfully bypassed 3-app limit for \(count) app(s)!"
                            )
                        } else {
                            Haptic.shared.notify(.error)
                            Alertinator.shared.alert(
                                title: "Bypass Failed",
                                body: message
                            )
                        }
                    }
                }
            }) {
                HStack {
                    Label {
                        Text("Bypass 3 App Limit")
                            .fontWeight(.medium)
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    if mgr.isAutoBypassing {
                        HStack(spacing: 6) {
                            if let status = mgr.autoBypassStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            ProgressView()
                        }
                    } else if let status = mgr.autoBypassStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(mgr.isAutoBypassing)

            NavigationLink(destination: AppsView()) {
                Label("Manage Sideloaded Apps", systemImage: "app.badge.checkmark")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Shortcuts Automation", systemImage: "arrow.triangle.branch")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = "lara://bypass-3-apps?callback=sidestore://"
                        Haptic.shared.play(.light)
                        copiedURLToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedURLToast = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedURLToast ? "checkmark" : "doc.on.doc")
                            Text(copiedURLToast ? "Copied" : "Copy URL")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.secondarySystemFill))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Text("URL: lara://bypass-3-apps?callback=sidestore://")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("Add 'Open URL' in your Shortcut before refreshing with SideStore.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var RCSection: some View {
        Group {
            #if !DISABLE_REMOTECALL
            Section {
                // init remotecall
                LabeledContent(content: {
                    if mgr.rcready {
                        Image(systemName: "checkmark.circle")
                    } else if mgr.rcrunning {
                        HStack {
                            Text("Running...")
                            ProgressView()
                        }
                    } else if mgr.rcfailed {
                        Image(systemName: "xmark.circle")
                    }
                }) {
                    Button("Initalize RemoteCall", action: {
                        mgr.rcinit(process: "SpringBoard", migbypass: false) { success in
                            if success {
                                mgr.logmsg("rc init succeeded!")
                                let pid = mgr.rccall(name: "getpid")
                                mgr.logmsg("remote getpid() returned: \(pid)")
                            } else {
                                mgr.logmsg("rc init failed")
                                mgr.rcfailed = true
                            }
                        }
                    })
                    .disabled(!mgr.dsready || isdebugged() || mgr.rcrunning || mgr.rcready)
                }
                
                // destroy remotecall
                if mgr.rcready {
                    Button("Destroy Remotecall", action: {
                        mgr.rcdestroy()
                    })
                }
            } header: {
                HeaderLabel(text: "RemoteCall", icon: "syringe")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let error = mgr.rcLastError ?? mgr.sbProc?.lastError {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                    if RemoteCall.isLiveContainerRuntime() && !RemoteCall.isLiveProcessRuntime() {
                        Text("RemoteCall needs a PAC-enabled LiveContainer launch context. The main exploit may still work when RemoteCall is unavailable.")
                    }
                    if isdebugged() {
                        Text("Not available when a debugger is attached.")
                    }
                    Text("RemoteCall is relatively unstable and may not work properly.")
                    if isIOS16() {
                        Text("iOS 16 tip: Open Control Center after tapping Initialize RemoteCall. This significantly improves the success rate and speed.")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Text("If initialization fails after about 2 minutes, respring, relaunch Lara, and try again.")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
                .font(.footnote)
            }
            #endif
        }
    }
    
    private var ActionsSection: some View {
        Section(header: HeaderLabel(text: "Actions", icon: "wrench.and.screwdriver")) {
            Button("Respring", action: {
                mgr.respring()
            })
            
            Button("Panic!", action: {
                mgr.panic()
            })
            
            if isdebugged() {
                Button("Detach Debugger", action: {
                    exit(0)
                })
            }
        }
    }
    
    private var DebugSection: some View {
        Group {
            if weonadebugbuild_pjbweouttahereexclamationmark {
                if mgr.dsready {
                    Section(header: HeaderLabel(text: "Debug Only", icon: "ant")) {
                        LabeledContent("kernel_base") {
                            Text(String(format: "0x%llx", mgr.kernbase))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("kernel_slide") {
                            Text(String(format: "0x%llx", mgr.kernslide))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var InlineLogsSection: some View {
        if selectedlogsdisplaymode == .content {
            Section {
                ScrollView {
                    if loggernobs {
                        let combined = logger.logs.joined(separator: "\n")
                        Text(combined)
                            .font(.system(size: 13, design: .monospaced))
                            .lineSpacing(1)
                            .textSelection(.enabled)
                            .onTapGesture {
                                UIPasteboard.general.string = combined
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    } else {
                        ForEach(Array(logger.logs.enumerated()), id: \.offset) { _, log in
                            Text(log)
                                .font(.system(size: 13, design: .monospaced))
                                .lineSpacing(1)
                                .textSelection(.enabled)
                                .onTapGesture {
                                    UIPasteboard.general.string = log
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                        }
                    }
                }
                .frame(height: 250)
                
                Button("Copy All") {
                    UIPasteboard.general.string = logger.logs.joined(separator: "\n\n")
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
                Button("Clear") {
                    logger.clear()
                }
                .foregroundColor(.red)
            } header: {
                HeaderLabel(text: "Logs", icon: "terminal")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(laramgr())
}
