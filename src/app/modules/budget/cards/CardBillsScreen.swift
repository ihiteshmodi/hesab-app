import HisaabCore
import SwiftUI

struct CardBillsScreen: View {
    let model: BudgetViewModel
    @State private var adding = false
    @State private var editingCard: HisaabCore.Card?
    @State private var payingLine: CardBillLine?
    @State private var errorMessage: String?

    var body: some View {
        CardScreen {
            if let bills = model.cardBills {
                CardPanel {
                    HStack {
                        Button("Previous Month", systemImage: "chevron.left") {
                            model.showCardBills(for: bills.month.shifted(by: -1))
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("previousCardMonth")
                        Spacer()
                        Text(bills.month.title).font(.headline)
                        Spacer()
                        Button("Next Month", systemImage: "chevron.right") {
                            model.showCardBills(for: bills.month.shifted(by: 1))
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("nextCardMonth")
                    }
                    .buttonStyle(.borderless)
                    CardCaption("Total due")
                    Text(IndianMoneyFormat.string(bills.totalDue)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .accessibilityIdentifier("cardTotalDue")
                    if bills.totalNewSpend > .zero {
                        Text("+ \(IndianMoneyFormat.string(bills.totalNewSpend)) new spend accruing for \(bills.month.shifted(by: 1).title)")
                            .font(.footnote).foregroundStyle(Theme.blue)
                            .accessibilityIdentifier("cardTotalNewSpend")
                    }
                }
                if !bills.hasCardSpending {
                    Text("No card spending in \(bills.month.title).").foregroundStyle(Theme.secondary).padding(.horizontal, 18)
                }
                CardGroup(footer: "Tap a card to edit its monthly due day or name.") {
                    ForEach(bills.lines, id: \.card.id) { line in
                        row(line, month: bills.month)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                }
            }
        }
        .cardNavigation("Card Bills")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Card", systemImage: "plus") { adding = true }
                    .accessibilityIdentifier("addCardButton")
            }
        }
        .sheet(isPresented: $adding) { CardFormSheet(model: model, editing: nil) }
        .sheet(item: $editingCard) { card in CardFormSheet(model: model, editing: card) }
        .sheet(item: $payingLine) { line in PayCardBillSheet(model: model, line: line) }
    }

    private func row(_ line: CardBillLine, month: CalendarDate.YearMonth) -> some View {
        let sub = subtitle(for: line, month: month)
        return HStack(spacing: 10) {
            Button { editingCard = line.card } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.card.name).foregroundStyle(Color.primary)
                    Text(sub.text).font(.footnote).foregroundStyle(sub.color).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editCard-\(line.card.name)")

            trailingAmounts(for: line)

            if line.due > .zero || line.isPaid {
                Button(line.isPaid && line.due == .zero ? "Paid ✓" : "Pay…") {
                    payingLine = line
                }
                .buttonStyle(AddPillStyle(done: line.isPaid && line.due == .zero))
                .accessibilityIdentifier("cardPaidButton")
            }
        }
        .rowPadding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardBillRow")
        .accessibilityLabel("\(line.card.name), bill \(IndianMoneyFormat.string(line.bill)), due \(IndianMoneyFormat.string(line.due))")
    }

    @ViewBuilder
    private func trailingAmounts(for line: CardBillLine) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            if line.due > .zero {
                Text(IndianMoneyFormat.string(line.due)).monospacedDigit()
                if line.newSpend > .zero {
                    Text("+ \(IndianMoneyFormat.string(line.newSpend)) new since \(line.cycleEnd.shortTitle)")
                        .font(.caption).foregroundStyle(Theme.blue).monospacedDigit()
                        .accessibilityIdentifier("cardNewSpendAmount")
                }
            } else if line.newSpend > .zero {
                Text(IndianMoneyFormat.string(line.newSpend))
                    .monospacedDigit().foregroundStyle(Theme.blue)
                    .accessibilityIdentifier("cardNewSpendAmount")
                Text("new since \(line.cycleEnd.shortTitle)")
                    .font(.caption).foregroundStyle(Theme.blue)
            } else {
                Text(IndianMoneyFormat.string(.zero)).monospacedDigit().foregroundStyle(Theme.secondary)
            }
        }
    }

    private func subtitle(for line: CardBillLine, month: CalendarDate.YearMonth) -> (text: String, color: Color) {
        if line.isPaid && line.due == .zero {
            return ("Paid \(IndianMoneyFormat.string(line.paid)) up to \(line.cycleEnd.shortTitle)", Theme.green)
        }
        if line.due > .zero {
            let carry = line.carriedOver > .zero ? "Includes \(IndianMoneyFormat.string(line.carriedOver)) carried over · " : ""
            if line.card.dueDay != nil {
                if month == CalendarDate(Date()).yearMonth {
                    let status = dueText(line.cycleEnd, windowDays: model.preferences.upcomingWindowDays)
                    let isPastDue = CalendarDate(Date()) > line.cycleEnd
                    let tone: Color = isPastDue ? Theme.red : (status.urgent ? Theme.orange : Theme.secondary)
                    return ("\(carry)Due \(line.cycleEnd.shortTitle) · \(status.text)", tone)
                }
                return ("\(carry)\(line.cycleStart.shortTitle) – \(line.cycleEnd.shortTitle)", Theme.secondary)
            }
            return (carry.isEmpty ? (line.isPaid ? "Paid \(IndianMoneyFormat.string(line.paid))" : "Not paid") : "\(carry)Not paid", Theme.secondary)
        }
        if let day = line.card.dueDay {
            return ("Due \(ordinalDay(day)) · Nothing due", Theme.secondary)
        }
        return ("Nothing due", Theme.secondary)
    }
}

extension HisaabCore.Card: @retroactive Identifiable {}
extension CardBillLine: @retroactive Identifiable {
    public var id: Int64 { card.id }
}

private func ordinalDay(_ day: Int) -> String {
    let suffix: String
    if (11...13).contains(day % 100) {
        suffix = "th"
    } else {
        switch day % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(day)\(suffix)"
}

private struct PayCardBillSheet: View {
    let model: BudgetViewModel
    let line: CardBillLine
    @Environment(\.dismiss) private var dismiss
    @State private var cutoffDate: Date
    @State private var errorMessage: String?

    init(model: BudgetViewModel, line: CardBillLine) {
        self.model = model
        self.line = line
        _cutoffDate = State(initialValue: (line.paidUpTo ?? line.cycleEnd).instant())
    }

    private var selectedDay: CalendarDate { CalendarDate(cutoffDate) }
    private var coveredAmount: Money? { model.cardPaymentAmount(line.card.id, upTo: selectedDay) }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "Charges up to this date are marked paid. Newer charges start a fresh counter for next month.") {
                    FieldRow("Paid up to") {
                        DatePicker("Paid up to", selection: $cutoffDate, displayedComponents: .date)
                            .labelsHidden()
                            .accessibilityIdentifier("cardCutoffDatePicker")
                    }
                    CardRow(title: "Amount covered (≤ \(selectedDay.shortTitle))") {
                        Text(coveredAmount.map(IndianMoneyFormat.string) ?? "—")
                            .monospacedDigit().fontWeight(.semibold)
                            .accessibilityIdentifier("cardCoveredAmount")
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                        .accessibilityIdentifier("payCardError")
                }
                Button(buttonTitle) {
                    errorMessage = model.markCardBillPaid(line.card.id, upTo: selectedDay)
                    if errorMessage == nil { dismiss() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("confirmCardPaidButton")

                if line.isPaid {
                    Button("Undo Payment", role: .destructive) {
                        errorMessage = model.unmarkCardBillPaid(line.card.id)
                        if errorMessage == nil { dismiss() }
                    }
                    .buttonStyle(GreyButtonStyle(tint: Theme.red))
                    .accessibilityIdentifier("unmarkCardPaidButton")
                }
            }
            .cardNavigation(line.card.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var buttonTitle: String {
        if let coveredAmount, coveredAmount > .zero {
            return "Mark \(IndianMoneyFormat.string(coveredAmount)) Paid up to \(selectedDay.shortTitle)"
        }
        return "Mark Paid up to \(selectedDay.shortTitle)"
    }
}

private struct CardFormSheet: View {
    let model: BudgetViewModel
    let editing: HisaabCore.Card?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var hasDueDay: Bool
    @State private var dueDay: Int
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    init(model: BudgetViewModel, editing: HisaabCore.Card?) {
        self.model = model
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _hasDueDay = State(initialValue: editing?.dueDay != nil)
        _dueDay = State(initialValue: editing?.dueDay ?? 20)
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "Set the day of the month this card's bill closes/falls due so post-cutoff spend starts a fresh counter.") {
                    TextField("Card name", text: $name).rowPadding().accessibilityIdentifier("cardNameField")
                    Toggle("Monthly due day", isOn: $hasDueDay).rowPadding()
                        .accessibilityIdentifier("cardDueDayToggle")
                    if hasDueDay {
                        FieldRow("Due day") {
                            Picker("Due day", selection: $dueDay) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(ordinalDay(day)) of month").tag(day)
                                }
                            }
                            .labelsHidden()
                            .accessibilityIdentifier("cardDueDayPicker")
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("cardError")
                }
                if editing != nil {
                    Button("Delete Card", role: .destructive) { confirmingDelete = true }
                        .buttonStyle(GreyButtonStyle(tint: Theme.red))
                        .accessibilityIdentifier("deleteCardButton")
                }
            }
            .cardNavigation(editing == nil ? "New Card" : "Edit Card")
            .confirmationDialog("Delete \(editing?.name ?? "this card")?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Card", role: .destructive) {
                    if let editing {
                        errorMessage = model.deleteCard(editing.id)
                        if errorMessage == nil { dismiss() }
                    }
                }
                .accessibilityIdentifier("confirmDeleteCardButton")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let chosen = hasDueDay ? dueDay : nil
                        errorMessage = editing.map { model.updateCard($0.id, name: name, dueDay: chosen) }
                            ?? model.addCard(name: name, dueDay: chosen)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveCardButton")
                }
            }
        }
    }
}
