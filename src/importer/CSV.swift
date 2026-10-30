/// Reads CSV the way spreadsheets write it: quoted fields may hold commas, doubled quotes and line breaks.
enum CSV {
    /// One array per record; blank lines are dropped, so a record's position is its line number.
    static func parse(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var pendingQuote = false

        func endField() {
            record.append(field)
            field = ""
        }
        func endRecord() {
            endField()
            if !(record.count == 1 && record[0].isEmpty) { records.append(record) }
            record = []
        }

        for character in text {
            if pendingQuote {
                pendingQuote = false
                if character == "\"" {
                    field.append("\"")
                    continue
                }
                inQuotes = false
            }
            if inQuotes {
                if character == "\"" { pendingQuote = true } else { field.append(character) }
                continue
            }
            switch character {
            case "\"": inQuotes = true
            case ",": endField()
            case "\n", "\r\n": endRecord()
            default: field.append(character)
            }
        }
        if !field.isEmpty || !record.isEmpty { endRecord() }
        return records
    }
}
