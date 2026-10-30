import HisaabCore
import SwiftUI

struct EntitiesScreen: View {
    let model: BudgetViewModel
    @State private var adding = false
    @State private var newName = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("entityError")
            }
            if model.entities.isEmpty {
                Text("No shops or people yet. They are saved when you add an expense.").foregroundStyle(.secondary)
            }
            ForEach(model.entities, id: \.id) { entity in
                NavigationLink {
                    EntityDetailScreen(model: model, entityID: entity.id)
                } label: {
                    HStack {
                        Text(entity.name)
                        Spacer()
                        Text("\(entity.expenseCount)").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("entityRow")
                .swipeActions {
                    Button("Delete", role: .destructive) { errorMessage = model.deleteEntity(entity.id) }
                }
            }
        }
        .navigationTitle("Entities")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Entity", systemImage: "plus") { newName = ""; adding = true }
                    .accessibilityIdentifier("addEntityButton")
            }
        }
        .alert("New Entity", isPresented: $adding) {
            TextField("Name", text: $newName).accessibilityIdentifier("entityNameField")
            Button("Save") { errorMessage = model.addEntity(name: newName) }
                .accessibilityIdentifier("saveEntityButton")
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct EntityDetailScreen: View {
    let model: BudgetViewModel
    let entityID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var newName = ""
    @State private var merging = false
    @State private var errorMessage: String?

    private var entity: EntitySummary? { model.entities.first { $0.id == entityID } }

    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            if let history = model.entityHistory(entityID) {
                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(IndianMoneyFormat.string(history.total)).monospacedDigit()
                    }
                }
                ForEach(history.months, id: \.month) { month in
                    Section {
                        ForEach(month.expenses, id: \.id) { expense in
                            HStack {
                                Text(expense.description)
                                Spacer()
                                Text(IndianMoneyFormat.string(expense.netAmount)).monospacedDigit()
                            }
                        }
                    } header: {
                        HStack {
                            Text(month.month.title)
                            Spacer()
                            Text(IndianMoneyFormat.string(month.total)).monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Button("Rename") { newName = entity?.name ?? ""; renaming = true }
                Button("Merge Into Another Entity") { merging = true }
            }
        }
        .navigationTitle(entity?.name ?? "Entity")
        .alert("Rename Entity", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save") { errorMessage = model.renameEntity(entityID, to: newName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Merge \(entity?.name ?? "") into", isPresented: $merging, titleVisibility: .visible) {
            ForEach(model.entities.filter { $0.id != entityID }, id: \.id) { target in
                Button(target.name) {
                    errorMessage = model.mergeEntities(entityID, into: target.id)
                    if errorMessage == nil { dismiss() }
                }
            }
        }
    }
}
