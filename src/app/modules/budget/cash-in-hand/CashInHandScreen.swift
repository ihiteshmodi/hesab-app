import HisaabCore
import SwiftUI

struct CashInHandScreen: View {
    let model: BudgetViewModel
    @State private var setting = false
    @State private var adding = false
    @State private var editingLine: CashLine?

    var body: some View {
        CardScreen {
            if let cash = model.cash {
                CardPanel {
                    CardCaption("Cash in hand")
                    Text(IndianMoneyFormat.string(cash.balance)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .accessibilityIdentifier("cashBalance")
                    if let warning = cash.warning {
                        Text(warning).foregroundStyle(Theme.orange).accessibilityIdentifier("cashWarning")
                    }
                }
                CardGroup(header: "Where it went") {
                    if cash.lines.isEmpty {
                        Text("Nothing yet. Keep a cash withdrawal or set what you are holding.")
                            .foregroundStyle(Theme.secondary).rowPadding()
                    }
                    ForEach(Array(cash.lines.enumerated()), id: \.offset) { _, line in
                        Button { if line.adjustmentID != nil { editingLine = line } } label: {
                            CardRow(title: line.description, subtitle: line.date.shortTitle) {
                                VStack(alignment: .trailing) {
                                    Text(IndianMoneyFormat.string(line.amount)).monospacedDigit()
                                    Text(IndianMoneyFormat.string(line.runningBalance))
                                        .font(.footnote).foregroundStyle(Theme.secondary).monospacedDigit()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cashLineRow")
                    }
                }
            }
            Button("Add Cash") { adding = true }.buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("addCashButton")
        }
        .cardNavigation("Cash in Hand")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Set Cash", systemImage: "pencil") { setting = true }
                    .accessibilityIdentifier("setCashButton")
            }
        }
        .sheet(isPresented: $setting) { SetCashSheet(model: model) }
        .sheet(isPresented: $adding) { AddCashSheet(model: model) }
        .sheet(item: $editingLine) { AddCashSheet(model: model, editing: $0) }
    }
}

extension CashLine: @retroactive Identifiable {
    public var id: Int64 { adjustmentID ?? 0 }
}

private struct AddCashSheet: View {
    let model: BudgetViewModel
    var editing: CashLine?
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var title: String
    @State private var date: Date
    @State private var removed: Bool
    @State private var errorMessage: String?

    init(model: BudgetViewModel, editing line: CashLine? = nil) {
        self.model = model
        editing = line
        _amountText = State(initialValue: line.map { IndianMoneyFormat.plain($0.amount < .zero ? .zero - $0.amount : $0.amount) } ?? "")
        _title = State(initialValue: line?.description ?? "")
        _date = State(initialValue: line?.date.instant() ?? Date())
        _removed = State(initialValue: (line?.amount ?? .zero) < .zero)
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("addCashAmountField")
                    TextField("Title", text: $title).rowPadding().accessibilityIdentifier("addCashTitleField")
                    if editing != nil {
                        FieldRow("Direction") {
                            Picker("Direction", selection: $removed) {
                                Text("Added").tag(false)
                                Text("Removed").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("addCashError")
                }
                if let editing, let id = editing.adjustmentID {
                    Button("Delete", role: .destructive) {
                        errorMessage = model.deleteCashAdjustment(id)
                        if errorMessage == nil { dismiss() }
                    }
                    .buttonStyle(GreyButtonStyle(tint: Theme.red))
                    .accessibilityIdentifier("deleteCashEntryButton")
                }
            }
            .cardNavigation(editing == nil ? "Add Cash" : "Edit Cash")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let id = editing?.adjustmentID {
                            errorMessage = model.updateCashAdjustment(id, amountText: amountText, removed: removed, title: title, date: CalendarDate(date))
                        } else {
                            errorMessage = model.addCash(amountText: amountText, title: title, date: CalendarDate(date))
                        }
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveAddCashButton")
                }
            }
        }
    }
}

private struct SetCashSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Cash you are holding", text: $amountText)
                        .keyboardType(.decimalPad)
                        .rowPadding()
                        .accessibilityIdentifier("setCashField")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                }
            }
            .cardNavigation("Set Cash in Hand")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.setCashInHand(amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveCashButton")
                }
            }
        }
    }
}
