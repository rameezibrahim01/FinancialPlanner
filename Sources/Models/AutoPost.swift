import Foundation
import SwiftData

/// Turns predictable money into real transactions automatically, once per month:
/// income posts on day 1, monthly recurring bills post on their due day — but
/// only once the day has actually arrived. Each posted item is a normal,
/// editable transaction flagged `autoPosted`. A per-source `lastPostedPeriod`
/// guards against double-posting and against re-posting something the user
/// deleted. Future-dated items stay in the dashboard's "Upcoming" until due.
enum AutoPost {
    @MainActor
    static func run(_ context: ModelContext) {
        let cal = SampleData.cal()
        let today = SampleData.referenceToday
        let year = cal.component(.year, from: today)
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        let period = year * 100 + month
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 28

        // Income sources → post on day 1 of the month.
        let sources = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
        for s in sources where s.lastPostedPeriod < period && day >= 1 {
            context.insert(Transaction(type: .income, amount: s.amount, categoryName: s.name,
                                       date: SampleData.date(year, month, 1),
                                       note: s.name, autoPosted: true))
            s.lastPostedPeriod = period
        }

        // Monthly recurring bills → post on their due day (once it's arrived).
        let recurring = (try? context.fetch(FetchDescriptor<Recurring>())) ?? []
        for r in recurring where r.autoPost && r.cadence == .monthly
            && r.lastPostedPeriod < period && day >= r.dueDay {
            let dueDay = min(r.dueDay, daysInMonth)
            context.insert(Transaction(type: .expense, amount: r.amount, categoryName: r.categoryName,
                                       date: SampleData.date(year, month, dueDay),
                                       note: r.name, autoPosted: true, recurringID: r.id))
            r.lastPostedPeriod = period
        }

        try? context.save()
    }
}
