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

    var body: some View {
        NavigationStack {
            Form {
                if editing == nil {
                    HStack {
                        Text("Expense").fontWeight(.semibold)
                        Spacer()
                        Button("Transfer instead") { switchToTransfer() }.accessibilityIdentifier("switchToTransferButton")
                    }
                }
                Section {
                    TextField("Title", text: $title).accessibilityIdentifier("tripExpenseTitleField")
                    HStack {
                        Text("Amount (\(trip.currency ?? "₹"))")
                        Spacer()
                        TextField("0", text: $amountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("tripExpenseAmountField")
                    }
                    if trip.currency != nil && paidBy == .me && paidWith == .bank {
                        HStack {
                            Text("Card charged me (₹)")
                            Spacer()
                            TextField("optional", text: $cardText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("tripExpenseCardField")
                        }
                    }
                    Picker("Paid by", selection: $paidBy) {
                        ForEach(participants, id: \.self) { Text(name($0)).tag($0) }
                    }
                    .accessibilityIdentifier("tripPaidByPicker")
                    if paidBy == .me {
                        Picker("Paid with", selection: $paidWith) {
                            Text("Card / bank").tag(ExpensePayment.bank)
                            Text(trip.currency == nil ? "Cash" : "Cash (\(trip.currency ?? ""))").tag(ExpensePayment.cash)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("tripPaidWithPicker")
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Button { choosingTag = true } label: {
                        HStack {
                            Text("Tag").foregroundStyle(.primary)
                            Spacer()
                            Text(tag.isEmpty ? "None" : tag).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("tripTagButton")
                } footer: {
                    if trip.currency != nil && paidBy == .me && paidWith == .bank {
                        Text("Optional. Gives this expense its real rupee cost; otherwise the trip rate is used.")
                    } else if paidWith == .cash && paidBy == .me {
                        Text("Counts for the split, but takes from cash instead of the main ledger.")
                    }
                }
                Section("Split between") {
                    Picker("Split", selection: $kind) {
                        ForEach(SplitKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("tripSplitKindPicker")
                    if kind != .items {
                        groupChips
                        ForEach(participants, id: \.self) { who in personRow(who) }
                    } else {
                        itemsEditor
                    }
                }
                Section("Notes and receipt") {
                    TextField("Notes", text: $note).accessibilityIdentifier("tripNoteField")
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(receipt != nil || (hadReceipt && !receiptTouched) ? "Replace receipt photo" : "Add receipt photo", systemImage: "photo")
                    }
                    if CameraPicker.isAvailable {
                        Button { takingPhoto = true } label: { Label("Take receipt photo", systemImage: "camera") }
                            .accessibilityIdentifier("takeReceiptPhotoButton")
                    }
                    if receipt != nil || (hadReceipt && !receiptTouched) {
                        Button("Remove receipt photo", role: .destructive) {
                            receipt = nil
                            receiptTouched = true
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("tripExpenseError") }
                }
            }
            .navigationTitle(editing == nil ? "Add" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(on ? Color.blue : Color.blue.opacity(0.1)))
                .foregroundStyle(on ? Color.white : Color.blue)
        }
        .buttonStyle(.plain)
    }

    private func personRow(_ who: Participant) -> some View {
        HStack {
            Button {
                if selected.contains(who) { selected.remove(who) } else { selected.insert(who) }
            } label: {
                Image(systemName: selected.contains(who) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(who) ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            Text(name(who))
            Spacer()
            if selected.contains(who) {
                switch kind {
                case .equally: Text(equalShareText).foregroundStyle(.secondary).monospacedDigit()
                case .shares: weightField(who, placeholder: "1", suffix: "shares")
                case .amounts: weightField(who, placeholder: "0", suffix: "")
                case .percent: weightField(who, placeholder: "0", suffix: "%")
                case .items: EmptyView()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splitRow-\(name(who))")
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
            if !suffix.isEmpty { Text(suffix).foregroundStyle(.secondary) }
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
        }
        .onDelete { items.remove(atOffsets: $0) }
        Button("Add Item") { items.append(ItemDraft(people: Set(participants))) }.accessibilityIdentifier("addItemButton")
        HStack {
            Text("Tax and service")
            Spacer()
            TextField("0", text: $extraText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110)
        }
        Text("Tax and service are shared in proportion to what each person ordered.").font(.footnote).foregroundStyle(.secondary)
    }

    // MARK: saving

    private func split() -> SplitMethod {
        let chosen = participants.filter { selected.contains($0) }
        switch kind {
        case .equally: return .equal(Set(chosen))
        case .shares: return .shares(Dictionary(uniqueKeysWithValues: chosen.map { ($0, Int(weights[$0] ?? "") ?? 1) }))
        case .amounts: return .exact(Dictionary(uniqueKeysWithValues: chosen.map { ($0, MoneyInput.parse(weights[$0] ?? "") ?? .zero) }))
        case .percent: return .percentage(Dictionary(uniqueKeysWithValues: chosen.map { ($0, Int(weights[$0] ?? "") ?? 0) }))
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
            List {
                Section {
                    TextField("Type a new tag", text: $typed).accessibilityIdentifier("newTagField")
                    Button("Use \"\(typed.trimmingCharacters(in: .whitespaces))\"") {
                        selection = typed.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("useNewTagButton")
                }
                Section("Pick one") {
                    Button("None") { selection = ""; dismiss() }
                    ForEach(model.tripTags(), id: \.name) { tag in
                        Button {
                            selection = tag.name
                            dismiss()
                        } label: {
                            HStack {
                                Text(tag.name).foregroundStyle(.primary)
                                Spacer()
                                if selection == tag.name { Image(systemName: "checkmark") }
                            }
                        }
                        .swipeActions {
                            if !tag.isDefault {
                                Button("Delete", role: .destructive) { errorMessage = model.deleteTripTag(tag.name) }
                            }
                        }
                        .accessibilityIdentifier("tag-\(tag.name)")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
