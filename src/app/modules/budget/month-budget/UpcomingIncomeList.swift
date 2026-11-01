import HisaabCore
import SwiftUI

/// Payouts and maturities coming up, one clean row each. Recording is here; editing a scheme stays in Portfolio.
struct UpcomingIncomeList: View {
    let model: BudgetViewModel
    @State private var recording: PayoutScheme?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardCaption(window)
                .padding(.bottom, 4)
            if model.upcomingIncome.isEmpty {
                Text("No income expected soon.").foregroundStyle(Theme.secondary).padding(.vertical, 12)
                    .accessibilityIdentifier("upcomingIncomeEmpty")
            }
            ForEach(Array(model.upcomingIncome.enumerated()), id: \.offset) { index, item in
                if index > 0 { Rectangle().fill(Theme.separator).frame(height: 1) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.scheme.name).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        Text(detail(item)).font(.footnote).lineLimit(1)
                            .foregroundStyle(item.kind == .matured ? Theme.red : Theme.secondary)
                        Spacer(minLength: 6)
                        if item.kind == .payout {
                            Text("about \(IndianMoneyFormat.string(item.scheme.payoutAmount))")
                                .monospacedDigit().font(.system(size: 15.5))
                            Button("Record") { recording = item.scheme }
                                .buttonStyle(AddPillStyle())
                                .accessibilityIdentifier("recordUpcomingPayoutButton")
                        }
                    }
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("upcomingIncomeRow")
            }
        }
        .sheet(item: $recording) { RecordPayoutSheet(model: model, scheme: $0) }
    }

    private var window: String {
        let payouts = model.preferences.payoutAlertDays
        let payoutText = payouts == 0 ? "payouts on the day" : "payouts within \(payouts) day\(payouts == 1 ? "" : "s")"
        return "Income you expect · \(payoutText), maturities within \(model.preferences.maturityAlertDays) days"
    }

    /// "Expected 3 Nov", "Matures in 53 days", "Matured 268 days ago".
    private func detail(_ item: UpcomingIncomeItem) -> String {
        let rest = String(item.label.dropFirst(item.scheme.name.count + 1))
        let text = item.kind == .payout
            ? String(rest.prefix { $0 != "," }).replacingOccurrences(of: "payout expected", with: "expected")
            : rest
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// Ticks the expected payouts and records each with its expected amount and date.
struct AddSeveralPayoutsSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var ticked: Set<Int64>
    @State private var errorMessage: String?

    init(model: BudgetViewModel) {
        self.model = model
        _ticked = State(initialValue: Set(model.upcomingIncome.filter { $0.kind == .payout }.map(\.scheme.id)))
    }

    private var payouts: [UpcomingIncomeItem] { model.upcomingIncome.filter { $0.kind == .payout } }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "Each payout is recorded with its expected amount and date.") {
                    if payouts.isEmpty { Text("No payouts expected soon.").foregroundStyle(Theme.secondary).rowPadding() }
                    ForEach(payouts, id: \.scheme.id) { item in
                        Button {
                            if ticked.contains(item.scheme.id) { ticked.remove(item.scheme.id) } else { ticked.insert(item.scheme.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: ticked.contains(item.scheme.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(Theme.blue).font(.title3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.scheme.name)
                                    Text("Payout expected \(item.date.shortTitle)").font(.footnote).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Text(IndianMoneyFormat.string(item.scheme.payoutAmount)).monospacedDigit()
                            }
                            .rowPadding()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("severalPayoutRow")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            }
            .cardNavigation("Add Several")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record Selected") { recordTicked() }.accessibilityIdentifier("confirmSeveralPayoutsButton")
                }
            }
        }
    }

    private func recordTicked() {
        for item in payouts where ticked.contains(item.scheme.id) {
            guard let draft = model.payoutDraft(item.scheme.id) else { continue }
            errorMessage = model.recordPayout(item.scheme.id, amountText: IndianMoneyFormat.plain(draft.amount), on: draft.date)
            if errorMessage != nil { return }
        }
        dismiss()
    }
}
