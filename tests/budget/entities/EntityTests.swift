import GRDB
import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/entities/entities.feature
struct EntityTests {
    @discardableResult
    private func spend(
        _ app: BudgetApp, _ description: String = "Item", rupees: Int = 100, entity: String = "", date: String = "2026-10-12",
        category: String = "Groceries", sub: String = "", method: PaymentMethod = .upi
    ) throws -> Expense {
        try app.addExpense(NewExpense(
            date: day(date), description: description, amount: .rupees(rupees), category: category, subCategory: sub,
            entity: entity, paymentMethod: method
        ))
    }

    private func entity(_ app: BudgetApp, _ name: String) throws -> EntitySummary {
        try #require(try app.entities().first { $0.name == name })
    }

    @Test func anExpenseWithAnEntitySavesTheEntity() throws {
        let app = try makeApp()

        let saved = try spend(app, "Sev bhaji", rupees: 116, entity: "Highway Dhaba")

        #expect(saved.entity == "Highway Dhaba")
        #expect(try entity(app, "Highway Dhaba").expenseCount == 1)
    }

    @Test func anExpenseCanHaveNoEntity() throws {
        let app = try makeApp()

        let saved = try spend(app, "Bread")

        #expect(saved.entity == nil)
        #expect(try app.entities().isEmpty)
    }

    @Test func savedEntitiesAreSuggestedAsSheTypes() throws {
        let app = try makeApp()
        for name in ["Amazon", "Meesho", "Highway Dhaba"] { try app.addEntity(name) }

        #expect(try app.suggestEntities("high") == ["Highway Dhaba"])
        #expect(try app.suggestEntities("A") == ["Amazon", "Highway Dhaba"])
        #expect(try app.suggestEntities("  ").isEmpty)
        #expect(try app.suggestEntities("zzz").isEmpty)
    }

    @Test func aNewEntityIsSavedOnTheSpotAndOfferedNextTime() throws {
        let app = try makeApp()

        try spend(app, entity: "Metro Dairy")

        #expect(try app.suggestEntities("met") == ["Metro Dairy"])
    }

    @Test func anEntityTypedInAnotherCaseReusesTheSavedSpelling() throws {
        let app = try makeApp()
        try app.addEntity("Amazon")

        let saved = try spend(app, entity: "  amazon ")

        #expect(saved.entity == "Amazon")
        #expect(try app.entities().count == 1)
    }

    @Test func editingAnExpenseToANewEntitySavesIt() throws {
        let app = try makeApp()
        let bought = try spend(app, entity: "Amazon")

        try app.updateExpense(bought.id!, NewExpense(
            date: bought.date, description: "Item", amount: bought.amount, category: "Groceries", entity: "Meesho"
        ))

        #expect(try app.entities().map(\.name) == ["Amazon", "Meesho"])
    }

    @Test func entityNamesAreUnique() throws {
        let app = try makeApp()
        try app.addEntity("Amazon")

        let error = #expect(throws: EntityError.self) { try app.addEntity("amazon") }

        #expect(error?.message == "An entity called Amazon already exists")
        #expect(throws: EntityError.nameMissing) { try app.addEntity("  ") }
    }

    @Test func anEntityRemembersHowItWasLastUsed() throws {
        let app = try makeApp()
        try spend(app, entity: "Highway Dhaba", date: "2026-10-01", category: "Fuel", method: .cash)
        try spend(app, entity: "Highway Dhaba", date: "2026-10-09", category: "Food & Dining", sub: "Restaurant", method: .bank("Visa Card"))

        let last = try #require(try app.entityLastUse(forName: "highway dhaba"))

        #expect(last.category == CategoryChoice(category: "Food & Dining", subCategory: "Restaurant"))
        #expect(last.paymentMethod == .bank("Visa Card"))
        #expect(try app.entityLastUse(forName: "Nobody") == nil)
    }

    @Test func oneEntitysSpendingIsShownMonthByMonth() throws {
        let app = try makeApp()
        try spend(app, "Order A", rupees: 1_200, entity: "Amazon", date: "2026-09-15")
        try spend(app, "Order B", rupees: 450, entity: "Amazon", date: "2026-10-03")
        try spend(app, "Elsewhere", rupees: 999, entity: "Meesho", date: "2026-10-04")

        let history = try app.entityHistory(try entity(app, "Amazon").id)

        #expect(history.total == .rupees(1_650))
        #expect(history.months.map(\.month) == [.init(year: 2026, month: 10), .init(year: 2026, month: 9)])
        #expect(history.months.map(\.total) == [.rupees(450), .rupees(1_200)])
        #expect(history.months[1].expenses.map(\.description) == ["Order A"])
    }

    @Test func renamingAnEntityUpdatesEveryExpense() throws {
        let app = try makeApp()
        for index in 1...5 { try spend(app, "Order \(index)", entity: "Amazon") }

        try app.renameEntity(try entity(app, "Amazon").id, to: "Amazon India")

        let expenses = try app.monthBudget(for: .init(year: 2026, month: 10)).expenses
        #expect(expenses.allSatisfy { $0.entity == "Amazon India" })
        #expect(try app.entities().map(\.name) == ["Amazon India"])
    }

    @Test func renamingToAnotherEntitysNameIsRefused() throws {
        let app = try makeApp()
        try app.addEntity("Amazon")
        let other = try app.addEntity("Meesho")

        #expect(throws: EntityError.nameTaken("Amazon")) { try app.renameEntity(other.id, to: "AMAZON") }
        #expect(throws: EntityError.nameMissing) { try app.renameEntity(other.id, to: " ") }
    }

    @Test func mergingTwoEntitiesMovesEveryExpense() throws {
        let app = try makeApp()
        try spend(app, "A", entity: "Amazon")
        try spend(app, "B", entity: "Amazon.in")
        let duplicate = try entity(app, "Amazon.in")

        try app.mergeEntities(duplicate.id, into: try entity(app, "Amazon").id)

        let expenses = try app.monthBudget(for: .init(year: 2026, month: 10)).expenses
        #expect(expenses.allSatisfy { $0.entity == "Amazon" })
        #expect(try app.entities().map(\.name) == ["Amazon"])
    }

    @Test func anEntityInUseCannotBeDeleted() throws {
        let app = try makeApp()
        for index in 1...5 { try spend(app, "Order \(index)", entity: "Amazon") }

        let error = #expect(throws: EntityError.self) { try app.deleteEntity(try entity(app, "Amazon").id) }

        #expect(error?.message == "5 expenses use Amazon. Merge it into another entity first.")
        #expect(try app.entities().count == 1)
    }

    @Test func oneExpenseReadsInTheSingular() throws {
        let app = try makeApp()
        try spend(app, entity: "Amazon")

        let error = #expect(throws: EntityError.self) { try app.deleteEntity(try entity(app, "Amazon").id) }

        #expect(error?.message == "1 expense uses Amazon. Merge it into another entity first.")
    }

    @Test func anUnusedEntityCanBeDeleted() throws {
        let app = try makeApp()
        let unused = try app.addEntity("Old shop")

        try app.deleteEntity(unused.id)

        #expect(try app.entities().isEmpty)
        #expect(throws: EntityError.notFound(unused.id)) { try app.deleteEntity(unused.id) }
        #expect(EntityError.notFound(1).message == "That entity no longer exists.")
    }

    @Test func entitiesAlreadyOnExpensesAreCarriedIntoTheListWhenTheAppUpgrades() throws {
        let queue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(queue, upTo: "v8-settings")
        try queue.write {
            try $0.execute(sql: """
                INSERT INTO expense (date, description, amount_paise, category, entity)
                VALUES ('2026-10-12', 'Old', 100, 'Groceries', 'Dairy Co'), ('2026-10-13', 'Old2', 100, 'Groceries', 'dairy co')
                """)
        }
        try AppDatabase.migrator.migrate(queue)

        let names = try queue.read { try String.fetchAll($0, sql: "SELECT name FROM entity") }

        #expect(names == ["Dairy Co"])
    }
}
