//
//  GroupMultiDeviceEventTest.swift
//  sdkTest
//
//  HIM-23838: group allow-list and mute-all multi-device events.
//

import SwiftUI
import HyphenateChat

private enum GroupMultiDeviceTestDefaults {
    static let memberId = "zuoyu02"
    static let eventTimeout: TimeInterval = 35
}

private enum GroupMultiDeviceTestRole: String, CaseIterable, Identifiable {
    case operatorDevice = "操作端"
    case observerDevice = "观察端"

    var id: String { rawValue }
}

private struct ExpectedGroupEvent {
    let rawValue: Int
    let name: String
}

private let expectedGroupEvents = [
    ExpectedGroupEvent(rawValue: 30, name: "添加白名单"),
    ExpectedGroupEvent(rawValue: 31, name: "移除白名单"),
    ExpectedGroupEvent(rawValue: 32, name: "全员禁言"),
    ExpectedGroupEvent(rawValue: 33, name: "解除全员禁言")
]

struct GroupMultiDeviceEventTest: View {
    @StateObject private var viewModel = GroupMultiDeviceEventTestViewModel()
    @StateObject private var tokenViewModel = EasemobUserTokenViewModel()

    var body: some View {
        Form {
            Section("设备角色") {
                Picker("设备角色", selection: $viewModel.role) {
                    ForEach(GroupMultiDeviceTestRole.allCases) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.segmented)
            }

            EasemobUserTokenForm(
                viewModel: tokenViewModel,
                isAppKeyLocked: viewModel.isSDKInitialized
            )

            Section("SDK 登录") {
                HStack(spacing: 12) {
                    statusLabel("SDK", ready: viewModel.isSDKInitialized)
                    statusLabel("登录", ready: viewModel.isLoggedIn)
                    statusLabel("连接", ready: viewModel.isConnected)
                }

                HStack(spacing: 12) {
                    actionButton("初始化", icon: "power", disabled: viewModel.isSDKInitialized) {
                        viewModel.initializeSDK(appKey: tokenViewModel.appKey)
                    }
                    actionButton(
                        "登录",
                        icon: "person.fill",
                        disabled: !viewModel.isSDKInitialized
                            || viewModel.isLoggedIn
                            || viewModel.isBusy
                            || tokenViewModel.isLoading
                    ) {
                        viewModel.login(using: tokenViewModel)
                    }
                    actionButton("退出", icon: "rectangle.portrait.and.arrow.right", disabled: !viewModel.isLoggedIn) {
                        viewModel.logout()
                    }
                }
            }

            Section("测试数据") {
                TextField("群成员 ID", text: $viewModel.memberId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("群 ID", text: $viewModel.groupId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if viewModel.role == .operatorDevice {
                Section("操作端") {
                    actionButton("创建测试群", icon: "person.3.fill", disabled: !viewModel.canCreateGroup) {
                        viewModel.createTestGroup()
                    }
                    actionButton("运行 30/31/32/33", icon: "play.fill", disabled: !viewModel.canRunOperations) {
                        viewModel.runOperations()
                    }
                    actionButton("销毁测试群", icon: "trash", disabled: !viewModel.canDestroyGroup) {
                        viewModel.destroyTestGroup()
                    }
                }
            } else {
                Section("观察端") {
                    actionButton(
                        viewModel.isObserving ? "停止观察" : "观察 30/31/32/33",
                        icon: viewModel.isObserving ? "stop.fill" : "eye.fill",
                        disabled: !viewModel.canToggleObservation
                    ) {
                        viewModel.toggleObservation()
                    }

                    if viewModel.isObserving {
                        ProgressView(value: Double(viewModel.observedEventCount), total: Double(expectedGroupEvents.count))
                    }
                }
            }

            Section("结果") {
                HStack {
                    Text(viewModel.resultTitle)
                        .font(.headline)
                    Spacer()
                    Image(systemName: viewModel.resultIcon)
                        .foregroundStyle(viewModel.resultColor)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(minHeight: 180, maxHeight: 320)

                Button(role: .destructive) {
                    viewModel.clearLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .disabled(viewModel.logs.isEmpty)
            }
        }
        .navigationTitle("群组多设备事件")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refreshConnectionState()
        }
    }

    private func statusLabel(_ title: String, ready: Bool) -> some View {
        Label(title, systemImage: ready ? "checkmark.circle.fill" : "circle")
            .font(.caption)
            .foregroundStyle(ready ? Color.green : Color.secondary)
    }

    private func actionButton(
        _ title: String,
        icon: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
    }
}

private final class GroupMultiDeviceEventTestViewModel: NSObject, ObservableObject {
    @Published var role: GroupMultiDeviceTestRole = .operatorDevice
    @Published var memberId = GroupMultiDeviceTestDefaults.memberId
    @Published var groupId = ""
    @Published private(set) var isSDKInitialized = false
    @Published private(set) var isLoggedIn = false
    @Published private(set) var isConnected = false
    @Published private(set) var isBusy = false
    @Published private(set) var isObserving = false
    @Published private(set) var observedEventCount = 0
    @Published private(set) var resultTitle = "尚未运行"
    @Published private(set) var resultIcon = "minus.circle"
    @Published private(set) var resultColor = Color.secondary
    @Published private(set) var logs: [String] = []

    private var expectedEventIndex = 0
    private var eventTimeoutWorkItem: DispatchWorkItem?

    var canCreateGroup: Bool {
        isLoggedIn && isConnected && !isBusy && !normalizedMemberId.isEmpty
    }

    var canRunOperations: Bool {
        isLoggedIn && isConnected && !isBusy && !normalizedGroupId.isEmpty && !normalizedMemberId.isEmpty
    }

    var canDestroyGroup: Bool {
        isLoggedIn && isConnected && !isBusy && !normalizedGroupId.isEmpty
    }

    var canToggleObservation: Bool {
        isObserving || (isLoggedIn && isConnected && !normalizedGroupId.isEmpty && !normalizedMemberId.isEmpty)
    }

    private var normalizedGroupId: String {
        groupId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedMemberId: String {
        memberId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        eventTimeoutWorkItem?.cancel()
        EMClient.shared().remove(self)
    }

    func initializeSDK(appKey: String) {
        let normalizedAppKey = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let appKeyParts = normalizedAppKey.split(
            separator: "#",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard appKeyParts.count == 2, !appKeyParts[0].isEmpty, !appKeyParts[1].isEmpty else {
            fail("AppKey must use the org#app format")
            return
        }

        let options = EMOptions(appkey: normalizedAppKey)
        options.enableConsoleLog = true
        options.usingHttpsOnly = false

        EMClient.shared().initializeSDK(with: options)
        EMClient.shared().addMultiDevices(delegate: self, queue: .main)
        isSDKInitialized = true
        refreshConnectionState()
        log("SDK initialized: \(normalizedAppKey)")
    }

    @MainActor
    func login(using tokenViewModel: EasemobUserTokenViewModel) {
        let normalizedUsername = tokenViewModel.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUsername.isEmpty else {
            fail("Username is empty")
            return
        }

        isBusy = true
        let usesExistingToken = !tokenViewModel.accessToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        log(usesExistingToken ? "Using provided user token" : "Fetching user token: \(normalizedUsername)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let token = try await tokenViewModel.resolveAccessToken()
                self.login(
                    username: normalizedUsername,
                    token: token,
                    source: usesExistingToken ? "provided" : "HTTP"
                )
            } catch {
                self.isBusy = false
                self.fail(error.localizedDescription)
            }
        }
    }

    private func login(username: String, token: String, source: String) {
        log("Login started: \(username), token source: \(source)")
        EMClient.shared().login(withUsername: username, token: token) { [weak self] loggedInUsername, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                if let error {
                    self.fail("Login failed: \(self.describe(error))")
                    return
                }
                self.isLoggedIn = true
                self.refreshConnectionState()
                self.log("Login succeeded: \(loggedInUsername)")
            }
        }
    }

    func logout() {
        stopObservation(logResult: false)
        isBusy = true
        EMClient.shared().logout(false) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                if let error {
                    self.fail("Logout failed: \(self.describe(error))")
                    return
                }
                self.isLoggedIn = false
                self.refreshConnectionState()
                self.log("Logout succeeded")
            }
        }
    }

    func refreshConnectionState() {
        isLoggedIn = EMClient.shared().isLoggedIn
        isConnected = EMClient.shared().isConnected
    }

    func createTestGroup() {
        guard let manager = EMClient.shared().groupManager else {
            fail("Group manager is unavailable")
            return
        }

        let configs = EMGroupConfigs()
        configs.maxUsers = 20
        configs.isPublic = false
        configs.isInviteNeedConfirm = false

        isBusy = true
        begin("Creating test group")
        manager.createGroup(
            withSubject: "HIM-23838-\(Int(Date().timeIntervalSince1970))",
            avatar: nil,
            description: "HIM-23838 multi-device event verification",
            invitees: [normalizedMemberId],
            message: "HIM-23838 verification",
            setting: configs
        ) { [weak self] group, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                if let error {
                    self.fail("Create group failed: \(self.describe(error))")
                    return
                }
                guard let createdGroupId = group?.groupId, !createdGroupId.isEmpty else {
                    self.fail("Create group returned an empty group ID")
                    return
                }
                self.groupId = createdGroupId
                self.pass("Group created: \(createdGroupId)")
            }
        }
    }

    func destroyTestGroup() {
        guard let manager = EMClient.shared().groupManager else {
            fail("Group manager is unavailable")
            return
        }

        let targetGroupId = normalizedGroupId
        isBusy = true
        log("Destroying group: \(targetGroupId)")
        manager.destroyGroup(targetGroupId) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                if let error {
                    self.fail("Destroy group failed: \(self.describe(error))")
                    return
                }
                self.pass("Group destroyed: \(targetGroupId)")
                self.groupId = ""
            }
        }
    }

    func runOperations() {
        isBusy = true
        begin("Operator verification started")
        log("Group: \(normalizedGroupId), member: \(normalizedMemberId), connected: \(EMClient.shared().isConnected)")
        addAllowListMember()
    }

    func toggleObservation() {
        if isObserving {
            stopObservation(logResult: true)
        } else {
            startObservation()
        }
    }

    func clearLogs() {
        logs.removeAll()
        resultTitle = "尚未运行"
        resultIcon = "minus.circle"
        resultColor = .secondary
    }

    private func startObservation() {
        expectedEventIndex = 0
        observedEventCount = 0
        isObserving = true
        begin("Observer armed")
        log("Group: \(normalizedGroupId), connected: \(EMClient.shared().isConnected)")
        scheduleTimeout(for: expectedGroupEvents[0])
    }

    private func stopObservation(logResult: Bool) {
        eventTimeoutWorkItem?.cancel()
        eventTimeoutWorkItem = nil
        isObserving = false
        if logResult {
            log("Observation stopped at \(observedEventCount)/\(expectedGroupEvents.count)")
        }
    }

    private func addAllowListMember() {
        guard let manager = EMClient.shared().groupManager else {
            finishOperationsWithFailure("Group manager is unavailable")
            return
        }

        log("[30] Adding allow-list member")
        manager.addWhiteListMembers([normalizedMemberId], fromGroup: normalizedGroupId) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finishOperationsWithFailure("[30] Operation failed: \(self.describe(error))")
                    return
                }
                self.verifyAllowList(containsMember: true, eventNumber: 30) {
                    self.removeAllowListMember()
                }
            }
        }
    }

    private func removeAllowListMember() {
        guard let manager = EMClient.shared().groupManager else {
            finishOperationsWithFailure("Group manager is unavailable")
            return
        }

        log("[31] Removing allow-list member")
        manager.removeWhiteListMembers([normalizedMemberId], fromGroup: normalizedGroupId) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finishOperationsWithFailure("[31] Operation failed: \(self.describe(error))")
                    return
                }
                self.verifyAllowList(containsMember: false, eventNumber: 31) {
                    self.muteAllMembers()
                }
            }
        }
    }

    private func muteAllMembers() {
        guard let manager = EMClient.shared().groupManager else {
            finishOperationsWithFailure("Group manager is unavailable")
            return
        }

        log("[32] Muting all members")
        manager.muteAllMembers(fromGroup: normalizedGroupId) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finishOperationsWithFailure("[32] Operation failed: \(self.describe(error))")
                    return
                }
                self.verifyMuteAll(expected: true, eventNumber: 32) {
                    self.unmuteAllMembers()
                }
            }
        }
    }

    private func unmuteAllMembers() {
        guard let manager = EMClient.shared().groupManager else {
            finishOperationsWithFailure("Group manager is unavailable")
            return
        }

        log("[33] Unmuting all members")
        manager.unmuteAllMembers(fromGroup: normalizedGroupId) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finishOperationsWithFailure("[33] Operation failed: \(self.describe(error))")
                    return
                }
                self.verifyMuteAll(expected: false, eventNumber: 33) {
                    self.isBusy = false
                    self.refreshConnectionState()
                    self.pass("Operator PASS: four operations and server readbacks succeeded")
                }
            }
        }
    }

    private func verifyAllowList(containsMember expected: Bool, eventNumber: Int, completion: @escaping () -> Void) {
        guard let manager = EMClient.shared().groupManager else {
            finishOperationsWithFailure("Group manager is unavailable")
            return
        }

        manager.getGroupWhiteListFromServer(withId: normalizedGroupId) { [weak self] members, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finishOperationsWithFailure("[\(eventNumber)] Allow-list readback failed: \(self.describe(error))")
                    return
                }
                let containsMember = members?.contains(self.normalizedMemberId) == true
                guard containsMember == expected else {
                    self.finishOperationsWithFailure(
                        "[\(eventNumber)] Allow-list readback mismatch: \(members ?? [])"
                    )
                    return
                }
                self.log("[\(eventNumber)] PASS, allow-list: \(members ?? [])")
                self.runAfterStepDelay(completion)
            }
        }
    }

    private func verifyMuteAll(expected: Bool, eventNumber: Int, completion: @escaping () -> Void) {
        guard let manager = EMClient.shared().groupManager else {
            finishOperationsWithFailure("Group manager is unavailable")
            return
        }

        manager.getGroupSpecificationFromServer(withId: normalizedGroupId) { [weak self] group, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.finishOperationsWithFailure("[\(eventNumber)] Group readback failed: \(self.describe(error))")
                    return
                }
                guard let group else {
                    self.finishOperationsWithFailure("[\(eventNumber)] Group readback returned nil")
                    return
                }
                guard group.isMuteAllMembers == expected else {
                    self.finishOperationsWithFailure(
                        "[\(eventNumber)] Mute-all readback mismatch: \(group.isMuteAllMembers)"
                    )
                    return
                }
                self.log("[\(eventNumber)] PASS, isMuteAllMembers: \(group.isMuteAllMembers)")
                self.runAfterStepDelay(completion)
            }
        }
    }

    private func runAfterStepDelay(_ completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: completion)
    }

    private func finishOperationsWithFailure(_ message: String) {
        isBusy = false
        refreshConnectionState()
        fail(message)
    }

    private func scheduleTimeout(for event: ExpectedGroupEvent) {
        eventTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isObserving else { return }
            self.stopObservation(logResult: false)
            self.fail("[\(event.rawValue)] FAIL: no event within 35 seconds")
        }
        eventTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + GroupMultiDeviceTestDefaults.eventTimeout,
            execute: workItem
        )
    }

    private func begin(_ message: String) {
        resultTitle = "运行中"
        resultIcon = "clock"
        resultColor = .orange
        log(message)
    }

    private func pass(_ message: String) {
        resultTitle = "PASS"
        resultIcon = "checkmark.circle.fill"
        resultColor = .green
        log(message)
    }

    private func fail(_ message: String) {
        resultTitle = "FAIL"
        resultIcon = "xmark.circle.fill"
        resultColor = .red
        log(message)
    }

    private func log(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("\(time)  \(message)")
    }

    private func describe(_ error: EMError) -> String {
        "\(error.errorDescription ?? "unknown") (code: \(error.code.rawValue))"
    }
}

extension GroupMultiDeviceEventTestViewModel: EMMultiDevicesDelegate {
    func multiDevicesGroupEventDidReceive(_ event: EMMultiDevicesEvent, groupId: String, ext: Any?) {
        guard isObserving else { return }
        guard groupId == normalizedGroupId else {
            log("Ignored event \(event.rawValue) for group \(groupId)")
            return
        }
        guard let eventIndex = expectedGroupEvents.firstIndex(where: { $0.rawValue == event.rawValue }) else {
            log("Ignored unrelated group event: \(event.rawValue)")
            return
        }
        guard eventIndex == expectedEventIndex else {
            stopObservation(logResult: false)
            fail("[\(event.rawValue)] FAIL: expected event \(expectedGroupEvents[expectedEventIndex].rawValue)")
            return
        }

        if event.rawValue == 30 || event.rawValue == 31 {
            guard let memberIds = ext as? [String], memberIds.contains(normalizedMemberId) else {
                stopObservation(logResult: false)
                fail("[\(event.rawValue)] FAIL: member ID missing from ext: \(String(describing: ext))")
                return
            }
        }

        eventTimeoutWorkItem?.cancel()
        let expectedEvent = expectedGroupEvents[eventIndex]
        observedEventCount += 1
        expectedEventIndex += 1
        log("[\(expectedEvent.rawValue)] PASS: \(expectedEvent.name), ext: \(String(describing: ext))")

        if expectedEventIndex == expectedGroupEvents.count {
            stopObservation(logResult: false)
            refreshConnectionState()
            pass("Observer PASS: received 30/31/32/33 in order")
        } else {
            scheduleTimeout(for: expectedGroupEvents[expectedEventIndex])
        }
    }
}

struct GroupMultiDeviceEventTest_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GroupMultiDeviceEventTest()
        }
    }
}
