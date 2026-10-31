import HisaabCore
import SwiftUI

struct CardBillsScreen: View {
    let model: BudgetViewModel
    @State private var adding = false
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
                }
                if !bills.hasCardSpending {
                    Text("No card spending in \(bills.month.title).").foregroundStyle(Theme.secondary).padding(.horizontal, 18)
                }
                CardGroup {
                    ForEach(bills.lines, id: \.card.id) { line in
                        CardRow(
                            title: line.card.name,
                            subtitle: line.isPaid ? "Paid \(IndianMoneyFormat.string(line.paid))" : "Not paid"
                        ) {
                            Text(IndianMoneyFormat.string(line.due)).monospacedDigit()
                            Button(line.isPaid && line.due == .zero ? "Unmark Paid" : "Mark Paid") {
                                errorMessage = model.setBillPaid(line.card.id, paid: !(line.isPaid && line.due == .zero))
                            }
                            .buttonStyle(AddPillStyle(done: line.isPaid && line.due == .zero))
                            .accessibilityIdentifier("cardPaidButton")
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("cardBillRow")
                        .accessibilityLabel("\(line.card.name), bill \(IndianMoneyFormat.string(line.bill)), due \(IndianMoneyFormat.string(line.due))")
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
        .sheet(isPresented: $adding) { NewCardSheet(model: model) }
    }
}

private struct NewCardSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Card name", text: $name).rowPadding().accessibilityIdentifier("cardNameField")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("cardError")
                }
            }
            .cardNavigation("New Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addCard(name: name)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveCardButton")
                }
            }
        }
    }
}
