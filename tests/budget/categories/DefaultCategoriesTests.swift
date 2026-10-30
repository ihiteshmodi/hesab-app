import Testing
@testable import HisaabCore

/// Scenario "A fresh install starts with a sensible default set" from
/// tests/budget/categories/categories.feature
struct DefaultCategoriesTests {
    @Test func aFreshInstallStartsWithTheAgreedParents() {
        #expect(DefaultCategories.tree.map(\.name) == [
            "Home & Utilities", "Food & Dining", "Groceries", "Health & Medical", "Transport", "Vehicle",
            "Fuel", "Insurance", "Entertainment & Movies", "Personal", "Family", "Lifestyle",
            "Shopping - Needs", "Shopping - Wants", "Technology & Gadgets", "Monthly Fixed Expenses",
            "Annual Fixed Expenses", "Miscellaneous",
        ])
    }

    @Test(arguments: [
        ("Home & Utilities", ["Electric", "Gas", "Internet", "Mortgage", "Rent", "Home maintenance", "Utilities", "Cell phone"]),
        ("Groceries", ["Ration", "Milk", "Biscuits"]),
        ("Transport", ["Ride share", "Train tickets", "Travel", "Flight tickets"]),
        ("Family", ["Family cash gifts"]),
        ("Fuel", []),
        ("Shopping - Needs", []),
    ] as [(String, [String])])
    func eachParentStartsWithItsSubCategories(parent: String, subs: [String]) throws {
        let group = try #require(DefaultCategories.tree.first { $0.name == parent })
        #expect(group.subCategories == subs)
    }

    @Test func noParentListsTheSameSubCategoryTwice() {
        for group in DefaultCategories.tree {
            #expect(Set(group.subCategories).count == group.subCategories.count, "\(group.name)")
        }
    }
}
