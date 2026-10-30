import Foundation
import GRDB

final class TripRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: people and groups

    func people(of tripID: Int64) throws -> [Person] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name FROM trip_person WHERE trip_id = ? ORDER BY id", arguments: [tripID])
                .map { Person(id: $0["id"], tripID: tripID, name: $0["name"]) }
        }
    }

    func addPerson(_ name: String, to tripID: Int64) throws -> Person {
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO trip_person (trip_id, name) VALUES (?, ?)", arguments: [tripID, name])
            return Person(id: db.lastInsertedRowID, tripID: tripID, name: name)
        }
    }

    func deletePerson(_ id: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM trip_person WHERE id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM trip_group_member WHERE participant_id = ?", arguments: [id])
        }
    }

    func groups(of tripID: Int64) throws -> [TripGroup] {
        try database.writer.read { db in
            let members = try Row.fetchAll(db, sql: """
                SELECT group_id, participant_id FROM trip_group_member
                JOIN trip_group ON trip_group.id = group_id WHERE trip_id = ?
                """, arguments: [tripID])
            return try Row.fetchAll(db, sql: "SELECT id, name FROM trip_group WHERE trip_id = ? ORDER BY id", arguments: [tripID])
                .map { row in
                    let id: Int64 = row["id"]
                    return TripGroup(
                        id: id, tripID: tripID, name: row["name"],
                        members: Set(members.filter { ($0["group_id"] as Int64) == id }.map { Participant(stored: $0["participant_id"]) })
                    )
                }
        }
    }

    func saveGroup(id: Int64?, tripID: Int64, name: String, members: Set<Participant>) throws {
        try database.writer.write { db in
            let groupID: Int64
            if let id {
                try db.execute(sql: "UPDATE trip_group SET name = ? WHERE id = ?", arguments: [name, id])
                try db.execute(sql: "DELETE FROM trip_group_member WHERE group_id = ?", arguments: [id])
                groupID = id
            } else {
                try db.execute(sql: "INSERT INTO trip_group (trip_id, name) VALUES (?, ?)", arguments: [tripID, name])
                groupID = db.lastInsertedRowID
            }
            for member in members {
                try db.execute(
                    sql: "INSERT INTO trip_group_member (group_id, participant_id) VALUES (?, ?)", arguments: [groupID, member.storedID]
                )
            }
        }
    }

    func deleteGroup(_ id: Int64) throws {
        try database.writer.write { db in try db.execute(sql: "DELETE FROM trip_group WHERE id = ?", arguments: [id]) }
    }

    // MARK: tags

    func customTags() throws -> [String] {
        try database.writer.read { db in try String.fetchAll(db, sql: "SELECT name FROM trip_tag ORDER BY rowid") }
    }

    func addTag(_ name: String) throws {
        try database.writer.write { db in try db.execute(sql: "INSERT OR IGNORE INTO trip_tag (name) VALUES (?)", arguments: [name]) }
    }

    func deleteTag(_ name: String) throws {
        try database.writer.write { db in try db.execute(sql: "DELETE FROM trip_tag WHERE name = ?", arguments: [name]) }
    }

    // MARK: trips

    func trips() throws -> [Trip] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM trip ORDER BY id").map(Self.trip)
        }
    }

    private static func trip(_ row: Row) throws -> Trip {
        Trip(
            id: row["id"], name: row["name"], currency: row["currency"],
            rate: (row["rate"] as String?).flatMap { Decimal(string: $0) }, ledgerName: row["ledger_name"],
            category: row["category"], subCategory: row["sub_category"],
            paymentMethod: PaymentMethod(
                name: row["payment_name"], source: PaymentMethod.Source(rawValue: row["payment_source"]) ?? .bank
            ),
            endDate: try (row["end_date"] as String?).map { try CalendarDate(isoString: $0) }, isSettled: row["settled"]
        )
    }

    func trip(_ id: Int64) throws -> Trip {
        let found = try database.writer.read { db in try Row.fetchOne(db, sql: "SELECT * FROM trip WHERE id = ?", arguments: [id]) }
        guard let found else { throw TripError.notFound(id) }
        return try Self.trip(found)
    }

    func insert(_ new: NewTrip, name: String, ledgerName: String) throws -> Trip {
        let id = try database.writer.write { db -> Int64 in
            try db.execute(sql: """
                INSERT INTO trip (name, currency, rate, ledger_name, category, sub_category, payment_name, payment_source, end_date)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    name, new.currency, new.rate.map { "\($0)" }, ledgerName, new.category, new.subCategory,
                    new.paymentMethod.name, new.paymentMethod.source.rawValue, new.endDate?.isoString,
                ])
            return db.lastInsertedRowID
        }
        return try trip(id)
    }

    func update(_ id: Int64, _ new: NewTrip, name: String, ledgerName: String) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                UPDATE trip SET name = ?, currency = ?, rate = ?, ledger_name = ?, category = ?, sub_category = ?,
                    payment_name = ?, payment_source = ?, end_date = ? WHERE id = ?
                """, arguments: [
                    name, new.currency, new.rate.map { "\($0)" }, ledgerName, new.category, new.subCategory,
                    new.paymentMethod.name, new.paymentMethod.source.rawValue, new.endDate?.isoString, id,
                ])
        }
    }

    func setSettled(_ id: Int64, _ settled: Bool) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE trip SET settled = ? WHERE id = ?", arguments: [settled, id])
            guard db.changesCount > 0 else { throw TripError.notFound(id) }
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in try db.execute(sql: "DELETE FROM trip WHERE id = ?", arguments: [id]) }
    }

    func linkedExpenseID(_ tripID: Int64) throws -> Int64? {
        try database.writer.read { db in
            try Int64.fetchOne(db, sql: "SELECT expense_id FROM trip WHERE id = ?", arguments: [tripID])
        }
    }

    func setLinkedExpense(_ tripID: Int64, _ expenseID: Int64?) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE trip SET expense_id = ? WHERE id = ?", arguments: [expenseID, tripID])
        }
    }

    // MARK: expenses

    func expenses(of tripID: Int64) throws -> [TripExpense] {
        try database.writer.read { db in
            let shares = try Row.fetchAll(db, sql: """
                SELECT trip_share.trip_expense_id, participant_id, trip_share.amount_paise FROM trip_share
                JOIN trip_expense ON trip_expense.id = trip_share.trip_expense_id WHERE trip_expense.trip_id = ?
                """, arguments: [tripID])
            let withReceipt = Set(try Int64.fetchAll(db, sql: """
                SELECT expense_id FROM trip_receipt JOIN trip_expense ON trip_expense.id = expense_id WHERE trip_id = ?
                """, arguments: [tripID]))
            return try Row.fetchAll(db, sql: "SELECT * FROM trip_expense WHERE trip_id = ? ORDER BY id", arguments: [tripID]).map { row in
                let id: Int64 = row["id"]
                var mine: [Participant: Money] = [:]
                for share in shares where (share["trip_expense_id"] as Int64) == id {
                    mine[Participant(stored: share["participant_id"])] = Money(paise: share["amount_paise"])
                }
                return TripExpense(
                    id: id, tripID: tripID, description: row["description"], date: try CalendarDate(isoString: row["date"]),
                    amount: Money(paise: row["amount_paise"]), paidBy: Participant(stored: row["paid_by"]),
                    paidWith: ExpensePayment(rawValue: row["paid_with"]) ?? .bank, shares: mine,
                    paidInHome: (row["paid_in_home_paise"] as Int?).map { Money(paise: $0) },
                    tag: row["tag"], note: row["note"], hasReceipt: withReceipt.contains(id)
                )
            }
        }
    }

    func tripID(ofExpense id: Int64) throws -> Int64 {
        try database.writer.read { db in
            guard let value = try Int64.fetchOne(db, sql: "SELECT trip_id FROM trip_expense WHERE id = ?", arguments: [id]) else {
                throw TripError.notFound(id)
            }
            return value
        }
    }

    func saveExpense(
        id: Int64?, tripID: Int64, description: String, date: CalendarDate, amount: Money, paidBy: Participant,
        paidWith: ExpensePayment, shares: [Participant: Money], paidInHome: Money?, tag: String, note: String
    ) throws -> TripExpense {
        let savedID = try database.writer.write { db -> Int64 in
            let savedID: Int64
            if let id {
                try db.execute(sql: """
                    UPDATE trip_expense SET description = ?, date = ?, amount_paise = ?, paid_by = ?, paid_in_home_paise = ?,
                        paid_with = ?, tag = ?, note = ? WHERE id = ?
                    """, arguments: [
                        description, date.isoString, amount.paise, paidBy.storedID, paidInHome?.paise, paidWith.rawValue, tag, note, id,
                    ])
                try db.execute(sql: "DELETE FROM trip_share WHERE trip_expense_id = ?", arguments: [id])
                savedID = id
            } else {
                try db.execute(sql: """
                    INSERT INTO trip_expense (trip_id, description, date, amount_paise, paid_by, paid_in_home_paise, paid_with, tag, note)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        tripID, description, date.isoString, amount.paise, paidBy.storedID, paidInHome?.paise, paidWith.rawValue, tag, note,
                    ])
                savedID = db.lastInsertedRowID
            }
            for (participant, share) in shares {
                try db.execute(sql: """
                    INSERT INTO trip_share (trip_expense_id, participant_id, amount_paise) VALUES (?, ?, ?)
                    """, arguments: [savedID, participant.storedID, share.paise])
            }
            return savedID
        }
        return try expenses(of: tripID).first { $0.id == savedID }!
    }

    func deleteExpense(_ id: Int64) throws {
        try database.writer.write { db in try db.execute(sql: "DELETE FROM trip_expense WHERE id = ?", arguments: [id]) }
    }

    func receipt(of expenseID: Int64) throws -> Data? {
        try database.writer.read { db in
            try Data.fetchOne(db, sql: "SELECT image FROM trip_receipt WHERE expense_id = ?", arguments: [expenseID])
        }
    }

    func setReceipt(_ image: Data?, of expenseID: Int64) throws {
        try database.writer.write { db in
            guard let image else {
                try db.execute(sql: "DELETE FROM trip_receipt WHERE expense_id = ?", arguments: [expenseID])
                return
            }
            try db.execute(
                sql: "INSERT OR REPLACE INTO trip_receipt (expense_id, image) VALUES (?, ?)", arguments: [expenseID, image]
            )
        }
    }

    // MARK: settlements and cash

    func settlements(of tripID: Int64) throws -> [TripSettlement] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM trip_settlement WHERE trip_id = ? ORDER BY id", arguments: [tripID]).map {
                TripSettlement(
                    id: $0["id"], tripID: tripID, personID: $0["person_id"], date: try CalendarDate(isoString: $0["date"]),
                    direction: SettlementDirection(rawValue: $0["direction"]) ?? .theyPaidMe,
                    method: SettlementMethod(rawValue: $0["method"]) ?? .bank, received: Money(paise: $0["amount_paise"]),
                    cleared: Money(paise: $0["cleared_paise"]), writtenOff: Money(paise: $0["written_off_paise"])
                )
            }
        }
    }

    func tripID(ofSettlement id: Int64) throws -> Int64 {
        try database.writer.read { db in
            guard let value = try Int64.fetchOne(db, sql: "SELECT trip_id FROM trip_settlement WHERE id = ?", arguments: [id]) else {
                throw TripError.notFound(id)
            }
            return value
        }
    }

    func addSettlement(
        tripID: Int64, personID: Int64, date: CalendarDate, direction: SettlementDirection, method: SettlementMethod,
        received: Money, cleared: Money, writtenOff: Money
    ) throws -> TripSettlement {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO trip_settlement
                    (trip_id, person_id, date, amount_paise, direction, method, cleared_paise, written_off_paise)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    tripID, personID, date.isoString, received.paise, direction.rawValue, method.rawValue, cleared.paise, writtenOff.paise,
                ])
            return TripSettlement(
                id: db.lastInsertedRowID, tripID: tripID, personID: personID, date: date, direction: direction, method: method,
                received: received, cleared: cleared, writtenOff: writtenOff
            )
        }
    }

    func deleteSettlement(_ id: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM trip_settlement WHERE id = ?", arguments: [id])
            guard db.changesCount > 0 else { throw TripError.notFound(id) }
        }
    }

    func cashAdjustments(of tripID: Int64) throws -> [CashAdjustment] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM trip_cash_adjustment WHERE trip_id = ? ORDER BY id", arguments: [tripID]).map {
                CashAdjustment(
                    id: $0["id"], date: try CalendarDate(isoString: $0["date"]), amount: Money(paise: $0["amount_paise"]),
                    note: $0["note"]
                )
            }
        }
    }

    func addCashAdjustment(tripID: Int64, date: CalendarDate, amount: Money) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO trip_cash_adjustment (trip_id, date, amount_paise, note) VALUES (?, ?, ?, 'Adjustment')
                """, arguments: [tripID, date.isoString, amount.paise])
        }
    }

    /// Rupee notes that moved through trips, as movements of the main Cash in Hand.
    func homeCashMovements() throws -> [CashAdjustment] {
        try database.writer.read { db in
            var movements: [CashAdjustment] = []
            let settlements = try Row.fetchAll(db, sql: """
                SELECT s.id, s.date, s.amount_paise, s.direction, t.name AS trip, p.name AS person
                FROM trip_settlement s JOIN trip t ON t.id = s.trip_id
                LEFT JOIN trip_person p ON p.id = s.person_id
                WHERE s.method = 'cash_home' OR (s.method = 'cash_trip' AND t.currency IS NULL)
                """)
            for row in settlements {
                let received = (row["direction"] as String) == SettlementDirection.theyPaidMe.rawValue
                let who = (row["person"] as String?) ?? "Someone"
                movements.append(CashAdjustment(
                    id: row["id"], date: try CalendarDate(isoString: row["date"]),
                    amount: Money(paise: received ? row["amount_paise"] : -(row["amount_paise"] as Int)),
                    note: received ? "\(row["trip"] as String): \(who) paid me in cash" : "\(row["trip"] as String): paid \(who) in cash"
                ))
            }
            let expenses = try Row.fetchAll(db, sql: """
                SELECT e.id, e.date, e.amount_paise, e.description, t.name AS trip
                FROM trip_expense e JOIN trip t ON t.id = e.trip_id
                WHERE t.currency IS NULL AND e.paid_by = 0 AND e.paid_with = 'cash'
                """)
            for row in expenses {
                movements.append(CashAdjustment(
                    id: row["id"], date: try CalendarDate(isoString: row["date"]),
                    amount: Money(paise: -(row["amount_paise"] as Int)), note: "\(row["trip"] as String): \(row["description"] as String)"
                ))
            }
            return movements
        }
    }
}
