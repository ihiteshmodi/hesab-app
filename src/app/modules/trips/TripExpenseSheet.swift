import HisaabCore
import PhotosUI
import SwiftUI

private enum SplitKind: String, CaseIterable {
    case equally = "Equally"
    case shares = "Shares"
    case amounts = "Amounts"
    case percent = "%"
    case items = "Items"
}

private struct ItemDraft: Identifiable {
    let id = UUID()
    var name = ""
    var amountText = ""
    var people: Set<Participant>
}

struct TripExpenseSheet: View {
    let model: BudgetViewModel
    let summary: TripSummary
    let editing: TripExpense?
    let switchToTransfer: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var cardText = ""
    @State private var paidBy = Participant.me
    @State private var paidWith = ExpensePayment.bank
    @State private var date = Date()
    @State private var tag = ""
    @State private var note = ""
    @State private var kind = SplitKind.equally
    @State private var selected: Set<Participant> = []
    @State private var weights: [Participant: String] = [:]
    @State private var items: [ItemDraft] = []
    @State private var extraText = ""
    @State private var receipt: Data?
    @State private var receiptTouched = false
    @State private var hadReceipt = false
    @State private var photo: PhotosPickerItem?
    @State private var takingPhoto = false
    @State private var choosingTag = false
    @State private var errorMessage: String?

    init(model: BudgetViewModel, summary: TripSummary, editing: TripExpense?, switchToTransfer: @escaping () -> Void) {
        self.model = model
        self.summary = summary
        self.editing = editing
        self.switchToTransfer = switchToTransfer
        let everyone = Set([Participant.me] + summary.members.map { Participant.person($0.id) })
        guard let editing else {
            _selected = State(initialValue: everyone)
            return
        }
        _title = State(initialValue: editing.description)
        _amountText = State(initialValue: IndianMoneyFormat.plain(editing.amount))
        _cardText = State(initialValue: editing.paidInHome.map { IndianMoneyFormat.plain($0) } ?? "")
        _paidBy = State(initialValue: editing.paidBy)
        _paidWith = State(initialValue: editing.paidWith)
        _date = State(initialValue: editing.date.instant())
        _tag = State(initialValue: editing.tag)
        _note = State(initialValue: editing.note)
        _kind = State(initialValue: .amounts)
        _selected = State(initialValue: Set(editing.shares.keys))
        _weights = State(initialValue: editing.shares.mapValues { IndianMoneyFormat.plain($0) })
        _hadReceipt = State(initialValue: editing.hasReceipt)
    }

    private var trip: Trip { summary.trip }
    private var participants: [Participant] { [.me] + summary.members.map { Participant.person($0.id) } }

    private func name(_ who: Participant) -> String {
        switch who {
        case .me: "Me"
        case .person(let id): summary.members.first { $0.id == id }?.name ?? "Someone"
        }
    }

    private var detailsFooter: String? {
        if trip.currency != nil && paidBy == .me && paidWith == .bank {
            return "Optional. Gives this expense its real rupee cost; otherwise the trip rate is used."
        }
        return paidWith == .cash && paidBy == .me ? "Counts for the split, but takes from cash instead of the main ledger." : nil
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                if editing == nil {
                    CardGroup {
                        HStack {
                            Text("Expense").fontWeight(.semibold)
                            Spacer()
                            Button("Transfer instead") { switchToTransfer() }.accessibilityIdentifier("switchToTransferButton")
                        }
                        .rowPadding()
                    }
                }
                CardGroup(footer: detailsFooter) {
                    TextField("Title", text: $title).accessibilityIdentifier("tripExpenseTitleField").rowPadding()
                    FieldRow("Amount (\(trip.currency ?? "₹"))") {
                        TextField("0", text: $amountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("tripExpenseAmountField")
                    }
                    if trip.currency != nil && paidBy == .me && paidWith == .bank {
                        FieldRow("Card charged me (₹)") {
                            TextField("optional", text: $cardText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("tripExpenseCardField")
                        }
                    }
                    FieldRow("Paid by") {
                        Picker("Paid by", selection: $paidBy) {
                            ForEach(participants, id: \.self) { Text(name($0)).tag($0) }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("tripPaidByPicker")
                    }
                    if paidBy == .me {
                        Picker("Paid with", selection: $paidWith) {
                            Text("Card / bank").tag(ExpensePayment.bank)
                            Text(trip.currency == nil ? "Cash" : "Cash (\(trip.currency ?? ""))").tag(ExpensePayment.cash)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("tripPaidWithPicker")
                        .rowPadding()
                    }
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
                    Button { choosingTag = true } label: {
                        CardRow(title: "Tag") { Text(tag.isEmpty ? "None" : tag).foregroundStyle(Theme.secondary) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tripTagButton")
                }
                CardGroup(
                    header: "Split between",
                    footer: kind == .items
                        ? "Tax and service are shared in proportion to what each person ordered."
                            + (items.isEmpty ? "" : " Touch and hold an item to delete it.")
                        : nil
                ) {
                    Picker("Split", selection: $kind) {
                        ForEach(SplitKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("tripSplitKindPicker")
                    .rowPadding()
                    // Numbers typed for one way of splitting mean something else in another, so a new way starts empty.
                    .onChange(of: kind) { weights = [:] }
                    if kind != .items {
                        groupChips
                        ForEach(participants, id: \.self) { who in personRow(who) }
                    } else {
                        itemsEditor
                    }
                }
                CardGroup(header: "Notes and receipt") {
                    TextField("Notes", text: $note).accessibilityIdentifier("tripNoteField").rowPadding()
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(receipt != nil || (hadReceipt && !receiptTouched) ? "Replace receipt photo" : "Add receipt photo", systemImage: "photo")
                    }
                    .rowPadding()
                    if CameraPicker.isAvailable {
                        Button { takingPhoto = true } label: { Label("Take receipt photo", systemImage: "camera").rowPadding() }
                            .accessibilityIdentifier("takeReceiptPhotoButton")
                    }
                    if receipt != nil || (hadReceipt && !receiptTouched) {
                        Button(role: .destructive) {
                            receipt = nil
                            receiptTouched = true
                        } label: { Text("Remove receipt photo").rowPadding() }
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).accessibilityIdentifier("tripExpenseError") }
            }
            .cardNavigation(editing == nil ? "Add" : "Edit Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("saveTripExpenseButton") }
            }
            .sheet(isPresented: $choosingTag) { TagPickerSheet(model: model, selection: $tag) }
            .fullScreenCover(isPresented: $takingPhoto) {
                CameraPicker { data in
                    if let small = ReceiptImage.compressed(data) {
                        receipt = small
                        receiptTouched = true
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photo) {
                guard let photo else { return }
                Task {
                    if let data = try? await photo.loadTransferable(type: Data.self), let small = ReceiptImage.compressed(data) {
                        receipt = small
                        receiptTouched = true
                    }
                }
            }
        }
    }

    // MARK: split pieces

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(summary.groups, id: \.id) { group in
                    chip(group.name, on: selected == group.members) { selected = group.members }
                        .accessibilityIdentifier("groupChip-\(group.name)")
                }
                chip("Everyone", on: selected == Set(participants)) { selected = Set(participants) }
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(on ? Theme.blue : Theme.blue.opacity(0.1)))
                .foregroundStyle(on ? Color.white : Theme.blue)
        }
        .buttonStyle(.plain)
    }

    private func personRow(_ who: Participant) -> some View {
        HStack {
            Button {
                if selected.contains(who) { selected.remove(who) } else { selected.insert(who) }
            } label: {
                Image(systemName: selected.contains(who) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(who) ? Theme.green : Theme.secondary)
            }
            .buttonStyle(.borderless)
            Text(name(who))
            Spacer()
            if selected.contains(who) {
                switch kind {
                case .equally: Text(equalShareText).foregroundStyle(Theme.secondary).monospacedDigit()
                case .shares: weightField(who, placeholder: "1", suffix: "shares")
                case .amounts: weightField(who, placeholder: autoText(who) ?? "0", suffix: "")
                case .percent: weightField(who, placeholder: autoText(who) ?? "0", suffix: "%")
                case .items: EmptyView()
                }
            }
        }
        .rowPadding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splitRow-\(name(who))")
    }

    /// The typed numbers as whole paise (amounts) or whole percent, with the one blank person given the rest.
    private var filled: [Participant: Int] {
        let chosen = participants.filter { selected.contains($0) }
        var typed: [Participant: Int] = [:]
        for who in chosen {
            let text = (weights[who] ?? "").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            typed[who] = kind == .percent ? Int(text) ?? 0 : MoneyInput.parse(text)?.paise ?? 0
        }
        let total = kind == .percent ? 100 : MoneyInput.parse(amountText)?.paise ?? 0
        return SplitRemainder.fill(typed, chosen: chosen, total: total)
    }

    private func autoText(_ who: Participant) -> String? {
        guard (weights[who] ?? "").trimmingCharacters(in: .whitespaces).isEmpty, let value = filled[who] else { return nil }
        return kind == .percent ? "\(value)" : IndianMoneyFormat.plain(Money(paise: value))
    }

    private var equalShareText: String {
        guard let amount = MoneyInput.parse(amountText), !selected.isEmpty else { return "" }
        return model.tripText(Money(paise: amount.paise / selected.count), trip)
    }

    private func weightField(_ who: Participant, placeholder: String, suffix: String) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: Binding(get: { weights[who] ?? "" }, set: { weights[who] = $0 }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                .accessibilityIdentifier("weightField-\(name(who))")
            if !suffix.isEmpty { Text(suffix).foregroundStyle(Theme.secondary) }
        }
    }

    @ViewBuilder private var itemsEditor: some View {
        ForEach($items) { $item in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Item", text: $item.name)
                    TextField("Amount", text: $item.amountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(participants, id: \.self) { who in
                            chip(name(who), on: item.people.contains(who)) {
                                if item.people.contains(who) { item.people.remove(who) } else { item.people.insert(who) }
                            }
                        }
                    }
                }
            }
            .rowPadding()
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) { items.removeAll { $0.id == item.id } }
            }
        }
        Button { items.append(ItemDraft(people: Set(participants))) } label: { Text("Add Item").rowPadding() }
            .accessibilityIdentifier("addItemButton")
        FieldRow("Tax and service") {
            TextField("0", text: $extraText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110)
        }
    }

    // MARK: saving

    private func split() -> SplitMethod {
        let chosen = participants.filter { selected.contains($0) }
        switch kind {
        case .equally: return .equal(Set(chosen))
        case .shares: return .shares(Dictionary(uniqueKeysWithValues: chosen.map { ($0, Int(weights[$0] ?? "") ?? 1) }))
        case .amounts: return .exact(Dictionary(uniqueKeysWithValues: chosen.map { ($0, Money(paise: filled[$0] ?? 0)) }))
        case .percent: return .percentage(Dictionary(uniqueKeysWithValues: chosen.map { ($0, filled[$0] ?? 0) }))
        case .items:
            return .items(
                items.map { SplitItem(name: $0.name, amount: MoneyInput.parse($0.amountText) ?? .zero, people: $0.people) },
                extra: MoneyInput.parse(extraText) ?? .zero
            )
        }
    }

    private func save() {
        let charge = cardText.trimmingCharacters(in: .whitespaces)
        let expense = NewTripExpense(
            description: title, date: CalendarDate(date), amount: MoneyInput.parse(amountText), paidBy: paidBy, paidWith: paidWith,
            split: split(), paidInHome: charge.isEmpty ? nil : MoneyInput.parse(charge), tag: tag, note: note,
            receipt: editing == nil ? receipt : nil
        )
        if let editing {
            errorMessage = model.updateTripExpense(editing.id, expense)
            if errorMessage == nil, receiptTouched { errorMessage = model.setTripReceipt(editing.id, receipt) }
        } else {
            errorMessage = model.addTripExpense(trip.id, expense)
        }
        if errorMessage == nil { dismiss() }
    }
}

struct TagPickerSheet: View {
    let model: BudgetViewModel
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Type a new tag", text: $typed).accessibilityIdentifier("newTagField").rowPadding()
                    Button {
                        selection = typed.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    } label: { Text("Use \"\(typed.trimmingCharacters(in: .whitespaces))\"").rowPadding() }
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("useNewTagButton")
                }
                CardGroup(header: "Pick one", footer: "Touch and hold a tag you added to delete it.") {
                    Button { selection = ""; dismiss() } label: { CardRow(title: "None") }.buttonStyle(.plain)
                    ForEach(model.tripTags(), id: \.name) { tag in
                        Button {
                            selection = tag.name
                            dismiss()
                        } label: {
                            CardRow(title: tag.name) {
                                if selection == tag.name { Image(systemName: "checkmark").foregroundStyle(Theme.blue) }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !tag.isDefault {
                                Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteTripTag(tag.name) }
                            }
                        }
                        .accessibilityIdentifier("tag-\(tag.name)")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
            }
            .cardNavigation("Tag")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
