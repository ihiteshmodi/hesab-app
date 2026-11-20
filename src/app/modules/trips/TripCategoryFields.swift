import HisaabCore
import SwiftUI

/// The app's own category and sub-category for a line item inside a trip; typing a new sub-category adds it to the main list.
struct TripCategoryFields: View {
    let model: BudgetViewModel
    @Binding var category: String
    @Binding var subCategory: String
    @State private var typingNew = false

    private static let newTag = "\u{1}new"

    private var subCategories: [String] {
        let saved = model.categories.first { $0.name == category }?.subCategories.map(\.name) ?? []
        guard !subCategory.isEmpty, !typingNew, !saved.contains(subCategory) else { return saved }
        return saved + [subCategory]
    }

    var body: some View {
        FieldRow("Category") {
            Picker("Category", selection: $category) {
                Text("None").tag("")
                ForEach(model.categories, id: \.name) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .accessibilityIdentifier("tripItemCategoryPicker")
        }
        .onChange(of: category) {
            subCategory = ""
            typingNew = false
        }
        if !category.isEmpty {
            FieldRow("Sub-category") {
                Picker("Sub-category", selection: Binding(
                    get: { typingNew ? Self.newTag : subCategory },
                    set: { choice in
                        typingNew = choice == Self.newTag
                        subCategory = typingNew ? "" : choice
                    }
                )) {
                    Text("None").tag("")
                    ForEach(subCategories, id: \.self) { Text($0).tag($0) }
                    Text("New sub-category…").tag(Self.newTag)
                }
                .labelsHidden()
                .accessibilityIdentifier("tripItemSubCategoryPicker")
            }
            if typingNew {
                TextField("New sub-category name", text: $subCategory).rowPadding()
                    .accessibilityIdentifier("tripItemNewSubCategoryField")
            }
        }
    }
}

extension TripExpense {
    /// "Food & Dining › Restaurant", or nil when it has no category.
    var categoryText: String? {
        category.isEmpty ? nil : [category, subCategory].filter { !$0.isEmpty }.joined(separator: " › ")
    }
}

extension TripPlanItem {
    var categoryText: String? {
        category.isEmpty ? nil : [category, subCategory].filter { !$0.isEmpty }.joined(separator: " › ")
    }
}
