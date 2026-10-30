import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/categories/categories.feature
struct CategoryTests {
    private func parent(_ app: BudgetApp, _ name: String) throws -> CategoryNode {
        try #require(try app.categories().first { $0.name == name })
    }

    private func sub(_ app: BudgetApp, _ parent: String, _ name: String) throws -> SubCategoryNode {
        try #require(try self.parent(app, parent).subCategories.first { $0.name == name })
    }

    @discardableResult
    private func spend(
        _ app: BudgetApp, _ description: String = "Item", category: String, sub: String = "", date: String = "2026-10-12",
        entity: String = ""
    ) throws -> Expense {
        try app.addExpense(NewExpense(
            date: day(date), description: description, amount: .rupees(100), category: category, subCategory: sub,
            entity: entity
        ))
    }

    @Test func aFreshInstallStartsWithTheDefaultSet() throws {
        let app = try makeApp()

        let tree = try app.categories().map { CategoryGroup(name: $0.name, subCategories: $0.subCategories.map(\.name)) }

        #expect(tree == DefaultCategories.tree)
    }

    @Test func aNewParentCanBeAddedWithAColourAndIcon() throws {
        let app = try makeApp()

        let pets = try app.addCategory(NewCategory(name: "Pet care", colour: "orange", icon: "pawprint"))

        let saved = try parent(app, "Pet care")
        #expect(saved.id == pets.id)
        #expect(saved.colour == "orange")
        #expect(saved.icon == "pawprint")
        #expect(saved.subCategories.isEmpty)
    }

    @Test func aSubCategoryCanBeAddedUnderAParent() throws {
        let app = try makeApp()
        let home = try parent(app, "Home & Utilities")

        try app.addSubCategory(home.id, "Water tax")

        #expect(try parent(app, "Home & Utilities").subCategories.map(\.name).contains("Water tax"))
    }

    @Test func theSameSubCategoryNameCanLiveUnderDifferentParents() throws {
        let app = try makeApp()

        try app.addSubCategory(try parent(app, "Home & Utilities").id, "Parking")

        #expect(try sub(app, "Vehicle", "Parking").id != (try sub(app, "Home & Utilities", "Parking")).id)
    }

    @Test(arguments: [
        ("home & utilities", "A category called home & utilities already exists"),
        ("  ", "Enter a name"),
    ])
    func duplicateOrEmptyParentNamesAreRefused(name: String, message: String) throws {
        let app = try makeApp()

        let error = #expect(throws: CategoryError.self) { try app.addCategory(NewCategory(name: name)) }

        #expect(error?.message == message)
    }

    @Test func aDuplicateSubCategoryNameIsRefusedNamingTheExistingOne() throws {
        let app = try makeApp()
        let home = try parent(app, "Home & Utilities")

        let error = #expect(throws: CategoryError.self) { try app.addSubCategory(home.id, "internet") }
        #expect(error?.message == "Home & Utilities already has an Internet")
        #expect(throws: CategoryError.nameMissing) { try app.addSubCategory(home.id, " ") }
    }

    @Test func renamingASubCategoryUpdatesEveryExpenseUnderIt() throws {
        let app = try makeApp()
        for index in 1...3 { try spend(app, "Bill \(index)", category: "Home & Utilities", sub: "Internet") }
        try spend(app, "Other", category: "Home & Utilities", sub: "Rent")

        try app.renameSubCategory(try sub(app, "Home & Utilities", "Internet").id, "Broadband")

        let expenses = try app.monthBudget(for: .init(year: 2026, month: 10)).expenses
        #expect(expenses.filter { $0.subCategory == "Broadband" }.count == 3)
        #expect(expenses.filter { $0.subCategory == "Internet" }.isEmpty)
        #expect(expenses.first { $0.description == "Other" }?.subCategory == "Rent")
    }

    @Test func renamingAParentUpdatesEveryExpenseUnderIt() throws {
        let app = try makeApp()
        try spend(app, category: "Fuel")

        try app.renameCategory(try parent(app, "Fuel").id, "Petrol")

        #expect(try app.monthBudget(for: .init(year: 2026, month: 10)).expenses.first?.category == "Petrol")
        #expect(throws: CategoryError.nameTaken("groceries")) { try app.renameCategory(try parent(app, "Petrol").id, "groceries") }
    }

    @Test func renamingToAnExistingSiblingIsRefused() throws {
        let app = try makeApp()
        let internet = try sub(app, "Home & Utilities", "Internet")

        #expect(throws: CategoryError.subCategoryTaken(parent: "Home & Utilities", existing: "Rent")) {
            try app.renameSubCategory(internet.id, "rent")
        }
    }

    @Test func mergingTwoSubCategoriesMovesEveryExpenseAndRemovesTheFirst() throws {
        let app = try makeApp()
        let transport = try parent(app, "Transport")
        let cab = try app.addSubCategory(transport.id, "Cab")
        try spend(app, "Trip", category: "Transport", sub: "Cab")
        try spend(app, "Auto", category: "Transport", sub: "Ride share")

        try app.mergeSubCategories(cab.id, into: try sub(app, "Transport", "Ride share").id)

        let expenses = try app.monthBudget(for: .init(year: 2026, month: 10)).expenses
        #expect(expenses.allSatisfy { $0.subCategory == "Ride share" })
        #expect(try parent(app, "Transport").subCategories.map(\.name).contains("Cab") == false)
    }

    @Test func aCategoryInUseCannotBeDeleted() throws {
        let app = try makeApp()
        for index in 1...12 { try spend(app, "Bill \(index)", category: "Home & Utilities", sub: "Internet") }
        let internet = try sub(app, "Home & Utilities", "Internet")

        let error = #expect(throws: CategoryError.self) { try app.deleteSubCategory(internet.id) }
        #expect(error?.message == "12 expenses use Internet. Move them to another sub-category first.")
        #expect(throws: CategoryError.self) { try app.deleteCategory(try parent(app, "Home & Utilities").id) }
        #expect(try sub(app, "Home & Utilities", "Internet").id == internet.id)
    }

    @Test func aParentInUseSaysToMoveItsExpensesToAnotherCategory() throws {
        let app = try makeApp()
        try spend(app, category: "Fuel")

        let error = #expect(throws: CategoryError.self) { try app.deleteCategory(try parent(app, "Fuel").id) }

        #expect(error?.message == "1 expense uses Fuel. Move them to another category first.")
    }

    @Test func anUnusedCategoryCanBeDeleted() throws {
        let app = try makeApp()
        try app.deleteSubCategory(try sub(app, "Food & Dining", "Coffee").id)
        try app.deleteCategory(try parent(app, "Personal").id)

        #expect(try parent(app, "Food & Dining").subCategories.map(\.name).contains("Coffee") == false)
        #expect(try app.categories().contains { $0.name == "Personal" } == false)
    }

    @Test func recentlyUsedSubCategoriesComeNewestFirstWithTheirParents() throws {
        let app = try makeApp()
        try spend(app, category: "Food & Dining", sub: "Coffee", date: "2026-10-01")
        try spend(app, category: "Home & Utilities", sub: "Internet", date: "2026-10-05")
        try spend(app, category: "Transport", sub: "Ride share", date: "2026-10-09")
        try spend(app, category: "Transport", sub: "Ride share", date: "2026-10-02")

        let recent = try app.recentCategories(limit: 3)

        #expect(recent == [
            CategoryChoice(category: "Transport", subCategory: "Ride share"),
            CategoryChoice(category: "Home & Utilities", subCategory: "Internet"),
            CategoryChoice(category: "Food & Dining", subCategory: "Coffee"),
        ])
    }

    @Test func aDescriptionUsedBeforeSuggestsItsCategory() throws {
        let app = try makeApp()
        try spend(app, "Milk", category: "Groceries", sub: "Milk", date: "2026-10-02")
        try spend(app, "Milk", category: "Groceries", sub: "Ration", date: "2026-10-09")

        #expect(try app.suggestCategory(forDescription: " milk ") == CategoryChoice(category: "Groceries", subCategory: "Ration"))
        #expect(try app.suggestCategory(forDescription: "Brand new thing") == nil)
        #expect(try app.suggestCategory(forDescription: "   ") == nil)
    }

    @Test func anEntitysUsualCategoryIsTheMostCommonOne() throws {
        let app = try makeApp()
        try spend(app, "A", category: "Home & Utilities", sub: "Internet", entity: "Fibre Co")
        try spend(app, "B", category: "Home & Utilities", sub: "Internet", entity: "Fibre Co")
        try spend(app, "C", category: "Fuel", entity: "Fibre Co")

        #expect(try app.suggestCategory(forEntity: "fibre co") == CategoryChoice(category: "Home & Utilities", subCategory: "Internet"))
        #expect(try app.suggestCategory(forEntity: "Nobody") == nil)
    }

    @Test func searchingFindsSubCategoriesWithTheirParentAndParentsByName() throws {
        let app = try makeApp()

        let found = try app.searchCategories("rep")

        #expect(found == [CategoryChoice(category: "Vehicle", subCategory: "Vehicle repairs")])
        #expect(try app.searchCategories("fuel") == [CategoryChoice(category: "Fuel", subCategory: "")])
        #expect(try app.searchCategories("  ").isEmpty)
    }

    @Test func errorsReadInPlainWords() {
        #expect(CategoryError.notFound(1).message == "That category no longer exists.")
    }
}
