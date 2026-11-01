import HisaabCore
import SwiftUI

private enum BorrowingList: String, CaseIterable {
    case active = "Active", repaid = "Repaid"
}

struct AmountToRepayScreen: View {
    let model: BudgetViewModel
    @State private var repaying: Int64?
    @State private var adding = false
    @State private var list = BorrowingList.active

    var body: some View {
        CardScreen {
            if let owed = model.amountToRepay {
                let active = owed.borrowings.filter { !$0.isRepaid }
                let repaid = owed.borrowings.filter(\.isRepaid)
                CardPanel {
                    CardCaption("Amount to repay")
                    Text(IndianMoneyFormat.string(owed.total)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .accessibilityIdentifier("repayTotal")
                }
                CardPanel {
                    PillSegments(selection: $list, options: BorrowingList.allCases.map { ($0, $0.rawValue) })
                        .accessibilityIdentifier("borrowingListPicker")
                }
                switch list {
                case .active:
                    if active.isEmpty {
                        Text("Nothing owed. Add a borrowing when you take money from someone.")
                            .foregroundStyle(Theme.secondary).padding(.horizontal, 18)
                            .accessibilityIdentifier("nothingOwed")
                    }
                    if !owed.lenders.isEmpty {
                        CardGroup(header: "Owed to") {
                            ForEach(owed.lenders, id: \.lender) { debt in
                                CardRow(title: debt.lender) { Text(IndianMoneyFormat.string(debt.owed)).monospacedDigit() }
                            }
                        }
                    }
                    if !active.isEmpty {
                        CardGroup(header: "Borrowings", footer: "Tap one to record a repayment.") { rows(active) }
                    }
                    Button("Add Borrowing") { adding = true }.buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("addBorrowingButton")
                case .repaid:
                    if repaid.isEmpty {
                        Text("Nothing paid back in full yet.").foregroundStyle(Theme.secondary).padding(.horizontal, 18)
                    } else {
                        CardGroup(header: "Paid back", footer: "Tap one to see its repayments.") { rows(repaid) }
                    }
                }
            }
        }
        .cardNavigation("Amount to Repay")
        .sheet(item: $repaying) { id in RepaymentSheet(model: model, borrowingID: id) }
        .sheet(isPresented: $adding) { BorrowingSheet(model: model) }
    }

    private func rows(_ lines: [BorrowingLine]) -> some View {
        ForEach(lines, id: \.borrowing.id) { line in
            Button { repaying = line.borrowing.id } label: {
                CardRow(
                    title: line.lender,
                    subtitle: "\(line.borrowing.date.shortTitle) · borrowed \(IndianMoneyFormat.string(line.borrowing.amount)) · \(line.borrowing.viaCash ? "Cash" : "Bank")"
                ) {
                    Text(line.isRepaid ? "Repaid" : IndianMoneyFormat.string(line.owed))
                        .foregroundStyle(line.isRepaid ? Theme.green : .primary)
                        .monospacedDigit()
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("borrowingRow")
        }
    }
}

/// Where money came from or went to.
private enum Pocket: String, CaseIterable {
    case bank = "Bank", cash = "Cash"
}

private struct BorrowingSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var lender = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var pocket = Pocket.bank
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Borrowed from", text: $lender).rowPadding().accessibilityIdentifier("borrowingLenderField")
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("borrowingAmountField")
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
                    FieldRow("Received as") {
                        Picker("Received as", selection: $pocket) {
                            ForEach(Pocket.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("borrowingPocketPicker")
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("borrowingError")
                }
            }
            .cardNavigation("Add Borrowing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addBorrowing(lender: lender, amountText: amountText, date: CalendarDate(date), viaCash: pocket == .cash)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveBorrowingButton")
                }
            }
        }
    }
}

private struct RepaymentSheet: View {
    let model: BudgetViewModel
    let borrowingID: Int64
    @State private var editingRepayment: Repayment?
    @State private var editingBorrowing: IncomeEntry?
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date()
    @State private var pocket: Pocket
    @State private var errorMessage: String?

    init(model: BudgetViewModel, borrowingID: Int64) {
        self.model = model
        self.borrowingID = borrowingID
        let viaCash = model.amountToRepay?.borrowings.first { $0.borrowing.id == borrowingID }?.borrowing.viaCash ?? false
        _pocket = State(initialValue: viaCash ? .cash : .bank)
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Amount repaid", text: $amountText)
                        .keyboardType(.decimalPad)
                        .rowPadding()
                        .accessibilityIdentifier("repaymentAmountField")
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
                    FieldRow("Paid from") {
                        Picker("Paid from", selection: $pocket) {
                            ForEach(Pocket.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("repaymentPocketPicker")
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                        .accessibilityIdentifier("repaymentError")
                }
                if let repayments = model.amountToRepay?.borrowings.first(where: { $0.borrowing.id == borrowingID })?.repayments,
                   !repayments.isEmpty {
                    CardGroup(header: "Repaid so far", footer: "Tap an entry to change it. Touch and hold to delete it.") {
                        ForEach(repayments, id: \.id) { repayment in
                            Button { editingRepayment = repayment } label: {
                                CardRow(title: repayment.date.shortTitle, subtitle: repayment.fromCash ? "From cash" : "From bank") {
                                    Text(IndianMoneyFormat.string(repayment.amount)).monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("repaymentRow")
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    errorMessage = model.deleteRepayment(repayment.id)
                                }
                            }
                        }
                    }
                }
            }
            .cardNavigation("Record Repayment")
            .sheet(item: $editingRepayment) { EditRepaymentSheet(model: model, repayment: $0) }
            .sheet(item: $editingBorrowing) { NewIncomeSheet(model: model, editing: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit Borrowing", systemImage: "pencil") {
                        editingBorrowing = model.amountToRepay?.borrowings.first { $0.borrowing.id == borrowingID }?.borrowing
                    }
                    .accessibilityIdentifier("editBorrowingButton")
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.recordRepayment(
                            borrowingID, amountText: amountText, on: CalendarDate(date), fromCash: pocket == .cash
                        )
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveRepaymentButton")
                }
            }
        }
    }
}

extension Repayment: @retroactive Identifiable {}

private struct EditRepaymentSheet: View {
    let model: BudgetViewModel
    let repayment: Repayment
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var date: Date
    @State private var pocket: Pocket
    @State private var errorMessage: String?

    init(model: BudgetViewModel, repayment: Repayment) {
        self.model = model
        self.repayment = repayment
        _amountText = State(initialValue: IndianMoneyFormat.plain(repayment.amount))
        _date = State(initialValue: repayment.date.instant())
        _pocket = State(initialValue: repayment.fromCash ? .cash : .bank)
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Amount repaid", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("editRepaymentAmountField")
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
                    FieldRow("Paid from") {
                        Picker("Paid from", selection: $pocket) {
                            ForEach(Pocket.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            }
            .cardNavigation("Edit Repayment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.updateRepayment(repayment.id, amountText: amountText, on: CalendarDate(date), fromCash: pocket == .cash)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveEditedRepaymentButton")
                }
            }
        }
    }
}
