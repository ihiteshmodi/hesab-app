import HisaabCore
import SwiftUI

/// Bills she pays herself that she has not yet sent; each row opens the date it was sent.
struct ToSendScreen: View {
    let model: BudgetViewModel
    @State private var sending: BillToSend?

    var body: some View {
        CardScreen {
            if model.billsToSend.isEmpty {
                CardPanel {
                    Text("Nothing to send. Bills you pay yourself appear here after you add them.")
                        .foregroundStyle(Theme.secondary)
                }
            } else {
                CardGroup {
                    CardRow(title: "Still to send") {
                        Text(IndianMoneyFormat.string(model.billsToSend.reduce(Money.zero) { $0 + $1.amount }))
                            .monospacedDigit().accessibilityIdentifier("stillToSend")
                    }
                }
                CardGroup(footer: "Tap a bill to say when you sent it.") {
                    ForEach(model.billsToSend, id: \.occurrenceID) { bill in
                        Button { sending = bill } label: {
                            CardRow(title: bill.billName, subtitle: "Due \(bill.dueDate.shortTitle)") {
                                Text(IndianMoneyFormat.string(bill.amount)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("toSendRow")
                    }
                }
            }
        }
        .cardNavigation("Pending to Send")
        .sheet(item: $sending) { SentSheet(model: model, bill: $0) }
    }
}

/// Ticks a bill she pays herself as sent, on the day she actually sent it.
struct SentSheet: View {
    let model: BudgetViewModel
    let bill: BillToSend
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    CardRow(title: bill.billName, subtitle: "Due \(bill.dueDate.shortTitle)") {
                        Text(IndianMoneyFormat.string(bill.amount)).monospacedDigit()
                    }
                    FieldRow("Sent on") {
                        DatePicker("Sent on", selection: $date, displayedComponents: .date).labelsHidden()
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            }
            .cardNavigation("Mark as Sent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.markBillSent(bill.occurrenceID, on: CalendarDate(date))
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveSentButton")
                }
            }
        }
    }
}
