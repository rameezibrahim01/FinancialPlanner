import Foundation

/// Parses a CSV of transactions into rows the importer can insert. Recognizes
/// the app's own export header (`Date,Type,Category,Amount,Note`) and common
/// bank-export shapes (a single signed Amount, or split Debit/Credit columns).
/// Everything runs on-device.
enum CSVImport {
    struct Row {
        var date: Date
        var type: TxType
        var category: String
        var amount: Double
        var note: String
    }

    static func parse(_ text: String) -> [Row] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerLine = lines.first else { return [] }
        let header = splitLine(headerLine).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        func col(_ names: [String]) -> Int? {
            for n in names { if let i = header.firstIndex(of: n) { return i } }
            return nil
        }
        let dateCol = col(["date", "transaction date", "posted date", "value date"])
        let typeCol = col(["type"])
        let catCol = col(["category"])
        let amtCol = col(["amount", "amount (aed)", "value"])
        let noteCol = col(["note", "notes", "description", "details", "merchant", "narration"])
        let debitCol = col(["debit", "withdrawal", "money out"])
        let creditCol = col(["credit", "deposit", "money in"])

        // Need at least a date and some amount column to be a transaction CSV.
        guard dateCol != nil, amtCol != nil || debitCol != nil || creditCol != nil else { return [] }

        var rows: [Row] = []
        for line in lines.dropFirst() {
            let f = splitLine(line)
            if f.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            func field(_ i: Int?) -> String {
                guard let i, i < f.count else { return "" }
                return f[i].trimmingCharacters(in: .whitespaces)
            }
            guard let date = parseDate(field(dateCol)) else { continue }

            var amount = 0.0
            var type: TxType = .expense
            if amtCol != nil {
                let raw = parseAmount(field(amtCol)) ?? 0
                let t = field(typeCol).lowercased()
                if t.contains("income") || t.contains("credit") || t.contains("deposit") {
                    type = .income; amount = abs(raw)
                } else if t.contains("expense") || t.contains("debit") {
                    type = .expense; amount = abs(raw)
                } else {
                    // No explicit type — a negative amount means an expense.
                    type = raw < 0 ? .expense : .income
                    amount = abs(raw)
                    if type == .income && raw > 0 && catCol == nil && field(typeCol).isEmpty {
                        // Bank exports often list spend as positive with no sign;
                        // default unsigned single-amount rows to expense.
                        type = .expense
                    }
                }
            } else {
                let debit = parseAmount(field(debitCol)) ?? 0
                let credit = parseAmount(field(creditCol)) ?? 0
                if credit > 0 { type = .income; amount = credit }
                else { type = .expense; amount = abs(debit) }
            }
            guard amount > 0 else { continue }

            let category = field(catCol).isEmpty ? (type == .income ? "Income" : "Other") : field(catCol)
            rows.append(Row(date: date, type: type, category: category, amount: amount, note: field(noteCol)))
        }
        return rows
    }

    // MARK: Field parsing

    static func parseDate(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        let df = DateFormatter()
        df.calendar = SampleData.cal()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy",
                    "yyyy/MM/dd", "d MMM yyyy", "dd MMM yyyy", "d/M/yyyy"] {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    static func parseAmount(_ s: String) -> Double? {
        var t = s.replacingOccurrences(of: ",", with: "")
        t = t.replacingOccurrences(of: "AED", with: "", options: .caseInsensitive)
        t = t.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("(") && t.hasSuffix(")") { t = "-" + t.dropFirst().dropLast() }   // (123) = -123
        return Double(t)
    }

    /// Splits one CSV line, honoring double-quoted fields and "" escapes.
    static func splitLine(_ line: String) -> [String] {
        var result: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    field.append("\""); i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                result.append(field); field = ""
            } else {
                field.append(c)
            }
            i += 1
        }
        result.append(field)
        return result
    }
}
