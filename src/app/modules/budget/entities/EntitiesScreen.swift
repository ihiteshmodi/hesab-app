import HisaabCore
import SwiftUI

struct EntitiesScreen: View {
    let model: BudgetViewModel
    @State private var adding = false
    @State private var newName = ""
    @State private var errorMessage: String?

    var body: some View {
        CardScreen {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("entityError")
            }
            if model.entities.isEmpty {
                CardPanel {
                    Text("No shops or people yet. They are saved when you add an expense.").foregroundStyle(Theme.secondary)
                }
            } else {
                CardGroup(footer: "Touch and hold an entry to delete it.") {
                    ForEach(model.entities, id: \.id) { entity in
                        LinkRow(title: entity.name, value: "\(entity.expenseCount)", identifier: "entityRow") {
                            EntityDetailScreen(model: model, entityID: entity.id)
                        }
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                errorMessage = model.deleteEntity(entity.id)
                            }
                        }
                    }
                }
            }
        }
        .cardNavigation("Entities")
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
        CardScreen {
            if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            if let history = model.entityHistory(entityID) {
                CardGroup {
                    CardRow(title: "Total") {
                        Text(IndianMoneyFormat.string(history.total)).monospacedDigit()
                    }
                }
                ForEach(history.months, id: \.month) { month in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(month.month.title)
                            Spacer()
                            Text(IndianMoneyFormat.string(month.total)).monospacedDigit()
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 18).padding(.top, 2)
                        CardGroup {
                            ForEach(month.expenses, id: \.id) { expense in
                                CardRow(title: expense.description) {
                                    Text(IndianMoneyFormat.string(expense.netAmount)).monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            CardGroup {
                ButtonRow(title: "Rename") { newName = entity?.name ?? ""; renaming = true }
                ButtonRow(title: "Merge Into Another Entity") { merging = true }
            }
        }
        .cardNavigation(entity?.name ?? "Entity")
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
