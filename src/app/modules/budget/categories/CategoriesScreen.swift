import HisaabCore
import SwiftUI

struct CategoriesScreen: View {
    let model: BudgetViewModel

    private enum Prompt: Identifiable {
        case addCategory
        case addSub(parent: CategoryNode)
        case renameCategory(CategoryNode)
        case renameSub(SubCategoryNode)

        var id: String {
            switch self {
            case .addCategory: "add"
            case .addSub(let parent): "sub-\(parent.id)"
            case .renameCategory(let node): "rename-\(node.id)"
            case .renameSub(let node): "rename-sub-\(node.id)"
            }
        }

        var title: String {
            switch self {
            case .addCategory: "New Category"
            case .addSub(let parent): "New Sub-category in \(parent.name)"
            case .renameCategory: "Rename Category"
            case .renameSub: "Rename Sub-category"
            }
        }

        var initialText: String {
            switch self {
            case .addCategory, .addSub: ""
            case .renameCategory(let node): node.name
            case .renameSub(let node): node.name
            }
        }
    }

    @State private var prompt: Prompt?
    @State private var promptText = ""
    @State private var mergeSource: SubCategoryNode?
    @State private var mergeChoices: [SubCategoryNode] = []
    @State private var search = ""
    @State private var errorMessage: String?

    var body: some View {
        CardScreen {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("categoryError")
            }
            ForEach(visible, id: \.id) { parent in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(parent.name).accessibilityIdentifier("categoryHeader")
                        Spacer()
                        Menu {
                            Button("Add Sub-category") { open(.addSub(parent: parent)) }
                            Button("Rename") { open(.renameCategory(parent)) }
                            Button("Delete", role: .destructive) { errorMessage = model.deleteCategory(parent.id) }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.body).foregroundStyle(Theme.blue)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 18).padding(.top, 2)
                    if !parent.subCategories.isEmpty {
                        CardGroup {
                            ForEach(parent.subCategories, id: \.id) { sub in
                                Text(sub.name)
                                    .rowPadding()
                                    .accessibilityIdentifier("subCategoryRow")
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            errorMessage = model.deleteSubCategory(sub.id)
                                        }
                                        Button("Rename", systemImage: "pencil") { open(.renameSub(sub)) }
                                        Button("Merge", systemImage: "arrow.triangle.merge") {
                                            mergeSource = sub
                                            mergeChoices = parent.subCategories.filter { $0.id != sub.id }
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            if !visible.isEmpty {
                Text("Touch and hold a sub-category to rename, merge or delete it.")
                    .font(.footnote).foregroundStyle(Theme.secondary).padding(.horizontal, 18)
            }
        }
        .searchable(text: $search, prompt: "Search categories")
        .cardNavigation("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Category", systemImage: "plus") { open(.addCategory) }
                    .accessibilityIdentifier("addCategoryButton")
            }
        }
        .alert(prompt?.title ?? "", isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })) {
            TextField("Name", text: $promptText).accessibilityIdentifier("categoryNameField")
            Button("Save") { submit() }.accessibilityIdentifier("saveCategoryButton")
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Merge \(mergeSource?.name ?? "") into", isPresented: Binding(
                get: { mergeSource != nil }, set: { if !$0 { mergeSource = nil } }
            ), titleVisibility: .visible
        ) {
            ForEach(mergeChoices, id: \.id) { target in
                Button(target.name) {
                    if let source = mergeSource { errorMessage = model.mergeSubCategories(source.id, into: target.id) }
                }
            }
        }
    }

    private var visible: [CategoryNode] {
        let text = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return model.categories }
        return model.categories.compactMap { parent in
            let subs = parent.subCategories.filter { $0.name.lowercased().contains(text) }
            if parent.name.lowercased().contains(text) { return parent }
            return subs.isEmpty ? nil : CategoryNode(
                id: parent.id, name: parent.name, colour: parent.colour, icon: parent.icon, subCategories: subs
            )
        }
    }

    private func open(_ next: Prompt) {
        promptText = next.initialText
        prompt = next
    }

    private func submit() {
        guard let prompt else { return }
        switch prompt {
        case .addCategory: errorMessage = model.addCategory(name: promptText, colour: "blue", icon: "tag")
        case .addSub(let parent): errorMessage = model.addSubCategory(parent.id, name: promptText)
        case .renameCategory(let node): errorMessage = model.renameCategory(node.id, to: promptText)
        case .renameSub(let node): errorMessage = model.renameSubCategory(node.id, to: promptText)
        }
    }
}
