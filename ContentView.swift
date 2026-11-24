import SwiftUI

@main
struct VendingManagerApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - データモデル

enum MachineStatus: String, Codable {
    case normal = "正常稼働"
    case needsRestock = "要補充"
    case outOfService = "故障・停止中"
}

struct DrinkSlot: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var price: Int
    var cost: Int
    var currentStock: Int
    var maxCapacity: Int
    var reorderThreshold: Int

    var needsRestock: Bool {
        currentStock <= reorderThreshold
    }

    var isSoldOut: Bool {
        currentStock <= 0
    }

    var profitPerUnit: Int {
        price - cost
    }
}

struct SaleLog: Identifiable, Hashable, Codable {
    let id: String
    let date: Date
    let machineId: String
    let machineName: String
    let productName: String
    let price: Int
    let profit: Int
}

struct VendingMachineItem: Identifiable, Hashable, Codable {
    let id: String
    var code: String
    var locationName: String
    var isOutOfService: Bool
    var cashBox: Int
    var slots: [DrinkSlot]

    var status: MachineStatus {
        if isOutOfService { return .outOfService }
        if slots.contains(where: { $0.needsRestock }) { return .needsRestock }
        return .normal
    }

    var totalStock: Int {
        slots.reduce(0) { $0 + $1.currentStock }
    }

    var totalCapacity: Int {
        slots.reduce(0) { $0 + $1.maxCapacity }
    }
}

// MARK: - メイン画面

struct ContentView: View {
    private let appDisplayName = "自販機管理運営"

    @State private var machines: [VendingMachineItem] = []
    @State private var salesLogs: [SaleLog] = []
    @State private var selectedMachineId: String?

    @State private var showAddMachine = false
    @State private var showAddSlot = false
    @State private var showSalesHistory = false
    @State private var showDeviceInfo = false

    @State private var selectedSlotForAction: DrinkSlot?
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    @State private var message = ""
    @State private var showMessage = false

    private var saveFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vending_manager_state.json")
    }

    private var selectedMachine: VendingMachineItem? {
        guard let id = selectedMachineId else { return machines.first }
        return machines.first(where: { $0.id == id }) ?? machines.first
    }

    private var totalSalesAmount: Int {
        salesLogs.reduce(0) { $0 + $1.price }
    }

    private var totalProfitAmount: Int {
        salesLogs.reduce(0) { $0 + $1.profit }
    }

    private var totalCashInBoxes: Int {
        machines.reduce(0) { $0 + $1.cashBox }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 上部サマリーヘッダー
                HStack(spacing: 12) {
                    VendingBadgeView(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appDisplayName).font(.headline)
                        Text("管理: \(machines.count)台 • 累計売上: ¥\(totalSalesAmount) (粗利 ¥\(totalProfitAmount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !salesLogs.isEmpty {
                        Button("CSV出力") {
                            exportCSV()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))

                if machines.isEmpty {
                    // 空状態（初期表示）
                    VStack(spacing: 16) {
                        VendingBadgeView(size: 84)
                        Text(appDisplayName).font(.title2.bold())
                        Text("設置した自販機の在庫補充・売上回収・稼働ステータスを一括管理します\nまずは管理する自販機を登録するか、サンプルデータを読み込んでください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button {
                            showAddMachine = true
                        } label: {
                            Label("自販機を新規登録", systemImage: "plus.rectangle.on.rectangle")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("サンプル自販機データを投入") {
                            loadSampleData()
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 自販機切替バー
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(machines) { machine in
                                let isSelected = machine.id == selectedMachine?.id
                                Button {
                                    selectedMachineId = machine.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(statusColor(machine.status))
                                            .frame(width: 8, height: 8)
                                        Text("\(machine.code) \(machine.locationName)")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))

                    if let machine = selectedMachine {
                        // 選択中自販機のステータス＆操作バー
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(machine.locationName)
                                            .font(.subheadline.bold())
                                        Text(machine.status.rawValue)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(statusColor(machine.status).opacity(0.15))
                                            .foregroundColor(statusColor(machine.status))
                                            .cornerRadius(4)
                                    }
                                    Text("金庫内売上: ¥\(machine.cashBox) • 総在庫: \(machine.totalStock)/\(machine.totalCapacity)本")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Menu {
                                    Button {
                                        restockAllSlots(in: machine.id)
                                    } label: {
                                        Label("全商品を一括満タン補充", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    Button {
                                        collectCash(from: machine.id)
                                    } label: {
                                        Label("売上金を集金する (¥\(machine.cashBox))", systemImage: "yensign.circle")
                                    }
                                    Button {
                                        toggleOutOfService(for: machine.id)
                                    } label: {
                                        Label(machine.isOutOfService ? "稼働再開にする" : "故障・メンテナンス停止にする", systemImage: "wrench.and.screwdriver")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        deleteMachine(id: machine.id)
                                    } label: {
                                        Label("この自販機を削除", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                            Divider()
                        }

                        // 商品スロット一覧
                        if machine.slots.isEmpty {
                            VStack(spacing: 12) {
                                Text("この自販機にはまだ商品が登録されていません")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button {
                                    showAddSlot = true
                                } label: {
                                    Label("商品レーンを追加", systemImage: "plus.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(machine.slots) { slot in
                                    HStack(spacing: 12) {
                                        Image(systemName: slot.isSoldOut ? "xmark.circle.fill" : (slot.needsRestock ? "exclamationmark.triangle.fill" : "cup.and.saucer.fill"))
                                            .foregroundColor(slot.isSoldOut ? .red : (slot.needsRestock ? .orange : .blue))
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(slot.name)
                                                    .font(.body.weight(.medium))
                                                    .lineLimit(1)
                                                if slot.isSoldOut {
                                                    Text("売切")
                                                        .font(.caption2.bold())
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1)
                                                        .background(Color.red.opacity(0.15))
                                                        .foregroundColor(.red)
                                                        .cornerRadius(4)
                                                } else if slot.needsRestock {
                                                    Text("要補充")
                                                        .font(.caption2.bold())
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1)
                                                        .background(Color.orange.opacity(0.15))
                                                        .foregroundColor(.orange)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            Text("¥\(slot.price) (原価¥\(slot.cost)) • 在庫 \(slot.currentStock)/\(slot.maxCapacity)本")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            simulatePurchase(machineId: machine.id, slotId: slot.id)
                                        } label: {
                                            Text("1本販売")
                                                .font(.caption.bold())
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(slot.isSoldOut || machine.isOutOfService)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSlotForAction = slot
                                    }
                                }
                                .onDelete { offsets in
                                    deleteSlots(at: offsets, in: machine.id)
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(appDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showDeviceInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        if !machines.isEmpty {
                            Button {
                                showSalesHistory = true
                            } label: {
                                Image(systemName: "chart.bar.doc.horizontal")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if selectedMachine != nil {
                            Button {
                                showAddSlot = true
                            } label: {
                                Image(systemName: "cart.badge.plus")
                            }
                        }
                        Button {
                            showAddMachine = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: loadState)
        .sheet(isPresented: $showAddMachine) {
            AddMachineSheet { code, location in
                let newMachine = VendingMachineItem(
                    id: UUID().uuidString,
                    code: code,
                    locationName: location,
                    isOutOfService: false,
                    cashBox: 0,
                    slots: []
                )
                machines.append(newMachine)
                selectedMachineId = newMachine.id
                saveState()
            }
        }
        .sheet(isPresented: $showAddSlot) {
            if let machine = selectedMachine {
                AddSlotSheet(machineName: machine.locationName) { newSlot in
                    if let idx = machines.firstIndex(where: { $0.id == machine.id }) {
                        machines[idx].slots.append(newSlot)
                        saveState()
                    }
                }
            }
        }
        .sheet(item: $selectedSlotForAction) { slot in
            if let machine = selectedMachine {
                SlotDetailSheet(
                    machineName: machine.locationName,
                    slot: slot,
                    onRestockFull: {
                        restockSingleSlot(machineId: machine.id, slotId: slot.id)
                    },
                    onUpdateStock: { updatedCount in
                        updateSingleSlotStock(machineId: machine.id, slotId: slot.id, newStock: updatedCount)
                    }
                )
            }
        }
        .sheet(isPresented: $showSalesHistory) {
            SalesHistorySheet(
                logs: salesLogs,
                totalSales: totalSalesAmount,
                totalProfit: totalProfitAmount,
                totalCashInBoxes: totalCashInBoxes,
                onClearLogs: {
                    salesLogs = []
                    saveState()
                }
            )
        }
        .sheet(isPresented: $showDeviceInfo) {
            DeviceEnvInfoView(appName: appDisplayName)
        }
        .sheet(isPresented: $showShare) {
            ShareView(items: shareItems)
        }
        .alert(appDisplayName, isPresented: $showMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    // MARK: - 業務ロジック

    private func statusColor(_ status: MachineStatus) -> Color {
        switch status {
        case .normal: return .green
        case .needsRestock: return .orange
        case .outOfService: return .red
        }
    }

    private func simulatePurchase(machineId: String, slotId: String) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }),
              let sIdx = machines[mIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }

        guard !machines[mIdx].isOutOfService else {
            message = "現在この自販機は停止中です。"
            showMessage = true
            return
        }

        var slot = machines[mIdx].slots[sIdx]
        guard slot.currentStock > 0 else {
            message = "「\(slot.name)」は売り切れです。"
            showMessage = true
            return
        }

        slot.currentStock -= 1
        machines[mIdx].slots[sIdx] = slot
        machines[mIdx].cashBox += slot.price

        let log = SaleLog(
            id: UUID().uuidString,
            date: Date(),
            machineId: machines[mIdx].code,
            machineName: machines[mIdx].locationName,
            productName: slot.name,
            price: slot.price,
            profit: slot.profitPerUnit
        )
        salesLogs.insert(log, at: 0)
        saveState()
    }

    private func restockSingleSlot(machineId: String, slotId: String) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }),
              let sIdx = machines[mIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
        let added = machines[mIdx].slots[sIdx].maxCapacity - machines[mIdx].slots[sIdx].currentStock
        machines[mIdx].slots[sIdx].currentStock = machines[mIdx].slots[sIdx].maxCapacity
        saveState()
        message = "「\(machines[mIdx].slots[sIdx].name)」を \(added)本 補充し、満タンにしました。"
        showMessage = true
    }

    private func updateSingleSlotStock(machineId: String, slotId: String, newStock: Int) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }),
              let sIdx = machines[mIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
        let maxCap = machines[mIdx].slots[sIdx].maxCapacity
        machines[mIdx].slots[sIdx].currentStock = min(max(0, newStock), maxCap)
        saveState()
    }

    private func restockAllSlots(in machineId: String) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }) else { return }
        var totalAdded = 0
        for sIdx in machines[mIdx].slots.indices {
            let diff = machines[mIdx].slots[sIdx].maxCapacity - machines[mIdx].slots[sIdx].currentStock
            if diff > 0 {
                totalAdded += diff
                machines[mIdx].slots[sIdx].currentStock = machines[mIdx].slots[sIdx].maxCapacity
            }
        }
        saveState()
        message = "\(machines[mIdx].locationName) の全レーンへ合計 \(totalAdded)本 補充しました。"
        showMessage = true
    }

    private func collectCash(from machineId: String) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }) else { return }
        let collected = machines[mIdx].cashBox
        machines[mIdx].cashBox = 0
        saveState()
        message = "\(machines[mIdx].locationName) から売上金 ¥\(collected) を回収しました。"
        showMessage = true
    }

    private func toggleOutOfService(for machineId: String) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }) else { return }
        machines[mIdx].isOutOfService.toggle()
        saveState()
    }

    private func deleteSlots(at offsets: IndexSet, in machineId: String) {
        guard let mIdx = machines.firstIndex(where: { $0.id == machineId }) else { return }
        machines[mIdx].slots.remove(atOffsets: offsets)
        saveState()
    }

    private func deleteMachine(id: String) {
        machines.removeAll { $0.id == id }
        if selectedMachineId == id {
            selectedMachineId = machines.first?.id
        }
        saveState()
    }

    private func exportCSV() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var csv = "日時,自販機コード,設置場所,商品名,販売価格,粗利\n"
        for log in salesLogs {
            let dateStr = formatter.string(from: log.date)
            csv += "\"\(dateStr)\",\"\(log.machineId)\",\"\(log.machineName)\",\"\(log.productName)\",\(log.price),\(log.profit)\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("自販機売上レポート.csv")
        if let data = csv.data(using: .utf8) {
            try? data.write(to: tempURL, options: .atomic)
            shareItems = [tempURL]
            showShare = true
        }
    }

    // MARK: - 永続化・サンプルデータ

    private struct SavedAppState: Codable {
        let machines: [VendingMachineItem]
        let salesLogs: [SaleLog]
    }

    private func saveState() {
        let state = SavedAppState(machines: machines, salesLogs: salesLogs)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: saveFileURL, options: .atomic)
        }
    }

    private func loadState() {
        if let data = try? Data(contentsOf: saveFileURL),
           let state = try? JSONDecoder().decode(SavedAppState.self, from: data) {
            machines = state.machines
            salesLogs = state.salesLogs
            if selectedMachineId == nil {
                selectedMachineId = machines.first?.id
            }
        }
    }

    private func loadSampleData() {
        let m1 = VendingMachineItem(
            id: UUID().uuidString,
            code: "VM-001",
            locationName: "半田駅前ビル 1F",
            isOutOfService: false,
            cashBox: 1480,
            slots: [
                DrinkSlot(id: UUID().uuidString, name: "緑茶 500ml", price: 160, cost: 65, currentStock: 3, maxCapacity: 20, reorderThreshold: 4),
                DrinkSlot(id: UUID().uuidString, name: "ブラック缶コーヒー", price: 130, cost: 45, currentStock: 12, maxCapacity: 15, reorderThreshold: 3),
                DrinkSlot(id: UUID().uuidString, name: "天然水 500ml", price: 120, cost: 35, currentStock: 0, maxCapacity: 24, reorderThreshold: 5),
                DrinkSlot(id: UUID().uuidString, name: "エナジードリンク 250ml", price: 210, cost: 95, currentStock: 8, maxCapacity: 12, reorderThreshold: 3)
            ]
        )
        let m2 = VendingMachineItem(
            id: UUID().uuidString,
            code: "VM-002",
            locationName: "工場棟 休憩スペース",
            isOutOfService: false,
            cashBox: 890,
            slots: [
                DrinkSlot(id: UUID().uuidString, name: "スポーツドリンク 500ml", price: 160, cost: 60, currentStock: 14, maxCapacity: 20, reorderThreshold: 4),
                DrinkSlot(id: UUID().uuidString, name: "微糖缶コーヒー", price: 130, cost: 45, currentStock: 2, maxCapacity: 15, reorderThreshold: 3)
            ]
        )
        machines = [m1, m2]
        selectedMachineId = m1.id
        salesLogs = [
            SaleLog(id: UUID().uuidString, date: Date().addingTimeInterval(-3600), machineId: "VM-001", machineName: "半田駅前ビル 1F", productName: "緑茶 500ml", price: 160, profit: 95),
            SaleLog(id: UUID().uuidString, date: Date().addingTimeInterval(-7200), machineId: "VM-002", machineName: "工場棟 休憩スペース", productName: "スポーツドリンク 500ml", price: 160, profit: 100)
        ]
        saveState()
    }
}

// MARK: - サブビュー・シート群

struct VendingBadgeView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: size * 0.54, weight: .medium))
                .foregroundColor(.blue)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.08), radius: size * 0.06, x: 0, y: size * 0.03)
    }
}

struct AddMachineSheet: View {
    let onAdd: (String, String) -> Void
    @Environment(\.presentationMode) private var presentationMode

    @State private var code = "VM-003"
    @State private var locationName = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("自販機の基本情報")) {
                    TextField("管理コード (例: VM-003)", text: $code)
                    TextField("設置場所 (例: 本社ロビー横)", text: $locationName)
                }
            }
            .navigationTitle("自販機を登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("登録") {
                        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
                        let trimmedLoc = locationName.trimmingCharacters(in: .whitespaces)
                        guard !trimmedCode.isEmpty, !trimmedLoc.isEmpty else { return }
                        onAdd(trimmedCode, trimmedLoc)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || locationName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct AddSlotSheet: View {
    let machineName: String
    let onAdd: (DrinkSlot) -> Void
    @Environment(\.presentationMode) private var presentationMode

    @State private var name = ""
    @State private var priceText = "150"
    @State private var costText = "60"
    @State private var maxCap = 20
    @State private var initialStock = 15
    @State private var threshold = 4

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("対象: \(machineName)")) {
                    TextField("商品名 (例: ウーロン茶 500ml)", text: $name)
                    HStack {
                        Text("販売価格 (円)")
                        Spacer()
                        TextField("150", text: $priceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("仕入原価 (円)")
                        Spacer()
                        TextField("60", text: $costText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section(header: Text("在庫・補充設定")) {
                    Stepper("最大収納数: \(maxCap)本", value: $maxCap, in: 1...50)
                    Stepper("初期在庫数: \(min(initialStock, maxCap))本", value: $initialStock, in: 0...maxCap)
                    Stepper("補充アラート基準: \(threshold)本以下", value: $threshold, in: 0...maxCap)
                }
            }
            .navigationTitle("商品レーンを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let cleanName = name.trimmingCharacters(in: .whitespaces)
                        let price = Int(priceText) ?? 150
                        let cost = Int(costText) ?? 60
                        guard !cleanName.isEmpty else { return }
                        let slot = DrinkSlot(
                            id: UUID().uuidString,
                            name: cleanName,
                            price: max(0, price),
                            cost: max(0, cost),
                            currentStock: min(initialStock, maxCap),
                            maxCapacity: maxCap,
                            reorderThreshold: threshold
                        )
                        onAdd(slot)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct SlotDetailSheet: View {
    let machineName: String
    let slot: DrinkSlot
    let onRestockFull: () -> Void
    let onUpdateStock: (Int) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var draftStock: Int = 0

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("\(machineName) • 商品詳細")) {
                    LabeledContentRow(label: "商品名", value: slot.name)
                    LabeledContentRow(label: "販売価格 / 原価", value: "¥\(slot.price) / ¥\(slot.cost)")
                    LabeledContentRow(label: "1本あたり粗利", value: "¥\(slot.profitPerUnit)")
                    LabeledContentRow(label: "補充アラート基準", value: "\(slot.reorderThreshold)本以下")
                }

                Section(header: Text("在庫数の調整")) {
                    Stepper("現在在庫: \(draftStock) / \(slot.maxCapacity)本", value: $draftStock, in: 0...slot.maxCapacity)

                    Button {
                        onUpdateStock(draftStock)
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("この在庫数で保存")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    Button {
                        onRestockFull()
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Label("最大容量（\(slot.maxCapacity)本）まで満タン補充", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("在庫補充・編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                draftStock = slot.currentStock
            }
        }
    }
}

struct SalesHistorySheet: View {
    let logs: [SaleLog]
    let totalSales: Int
    let totalProfit: Int
    let totalCashInBoxes: Int
    let onClearLogs: () -> Void

    @Environment(\.presentationMode) private var presentationMode

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("全体集計サマリー")) {
                    LabeledContentRow(label: "累計売上高", value: "¥\(totalSales)")
                    LabeledContentRow(label: "累計粗利益", value: "¥\(totalProfit)")
                    LabeledContentRow(label: "全自販機の未回収金庫合計", value: "¥\(totalCashInBoxes)")
                }

                Section(header: Text("販売履歴 (\(logs.count)件)")) {
                    if logs.isEmpty {
                        Text("販売履歴はまだありません")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(logs) { log in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.productName)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(dateFormatter.string(from: log.date)) • \(log.machineId) \(log.machineName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("¥\(log.price)")
                                        .font(.subheadline.bold())
                                    Text("粗利 +¥\(log.profit)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("売上・収益レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !logs.isEmpty {
                        Button("履歴リセット", role: .destructive) {
                            onClearLogs()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct DeviceEnvInfoView: View {
    let appName: String
    @Environment(\.presentationMode) private var presentationMode

    private var device: UIDevice { UIDevice.current }
    private var bundleID: String { Bundle.main.bundleIdentifier ?? "-" }
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("自分の端末・iOS環境")) {
                    LabeledContentRow(label: "OS", value: "\(device.systemName) \(device.systemVersion)")
                    LabeledContentRow(label: "端末種別", value: device.localizedModel)
                    LabeledContentRow(label: "モデル名", value: device.model)
                }
                Section(header: Text("インストール環境・アプリ情報")) {
                    LabeledContentRow(label: "表示名", value: appName)
                    LabeledContentRow(label: "Bundle ID", value: bundleID)
                    LabeledContentRow(label: "バージョン", value: appVersion)
                    LabeledContentRow(label: "導入経路", value: "GitHub Actions / KSign 署名導入")
                }
            }
            .navigationTitle("環境・バージョン情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

private struct LabeledContentRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct ShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
