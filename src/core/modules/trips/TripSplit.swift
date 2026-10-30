import Foundation

/// Turns what was typed for a shared expense into one share per person, adding up exactly to the amount.
enum TripSplit {
    static func shares(
        _ split: SplitMethod, amount: Money, allowed: Set<Participant>, name: (Participant) -> String
    ) throws -> [Participant: Money] {
        let chosen = people(in: split)
        guard !chosen.isEmpty else { throw TripError.nobodySharing }
        if let outsider = chosen.first(where: { !allowed.contains($0) }) { throw TripError.notAMember(name(outsider)) }

        switch split {
        case .equal:
            return distribute(amount.paise, weights: chosen.map { ($0, 1) })
        case .shares(let given):
            guard given.values.allSatisfy({ $0 >= 1 }) else { throw TripError.sharesInvalid }
            return distribute(amount.paise, weights: chosen.map { ($0, given[$0]!) })
        case .exact(let given):
            guard given.values.reduce(Money.zero, +) == amount else { throw TripError.sharesMismatch(amount) }
            return given
        case .percentage(let given):
            guard given.values.reduce(0, +) == 100 else { throw TripError.percentagesMismatch }
            return distribute(amount.paise, weights: chosen.map { ($0, given[$0]!) })
        case .items(let items, let extra):
            guard items.reduce(Money.zero, { $0 + $1.amount }) + extra == amount else { throw TripError.itemsMismatch(amount) }
            var ordered: [Participant: Int] = [:]
            for item in items {
                for (who, part) in distribute(item.amount.paise, weights: item.people.sorted { $0.order < $1.order }.map { ($0, 1) }) {
                    ordered[who, default: 0] += part.paise
                }
            }
            let weights = chosen.map { ($0, ordered[$0] ?? 0) }
            let extras = weights.reduce(0) { $0 + $1.1 } > 0
                ? distribute(extra.paise, weights: weights)
                : distribute(extra.paise, weights: chosen.map { ($0, 1) })
            return Dictionary(uniqueKeysWithValues: chosen.map { ($0, Money(paise: (ordered[$0] ?? 0) + (extras[$0]?.paise ?? 0))) })
        }
    }

    private static func people(in split: SplitMethod) -> [Participant] {
        switch split {
        case .equal(let set): set.sorted { $0.order < $1.order }
        case .shares(let given): given.keys.sorted { $0.order < $1.order }
        case .exact(let given): given.keys.sorted { $0.order < $1.order }
        case .percentage(let given): given.keys.sorted { $0.order < $1.order }
        case .items(let items, _): Set(items.flatMap(\.people)).sorted { $0.order < $1.order }
        }
    }

    /// Proportional to the weights; the paise left over go one each to the first people.
    private static func distribute(_ paise: Int, weights: [(Participant, Int)]) -> [Participant: Money] {
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return Dictionary(uniqueKeysWithValues: weights.map { ($0.0, Money.zero) }) }
        var result = weights.map { ($0.0, paise * $0.1 / total) }
        var left = paise - result.reduce(0) { $0 + $1.1 }
        var index = 0
        while left > 0 {
            if weights[index].1 > 0 {
                result[index].1 += 1
                left -= 1
            }
            index = (index + 1) % result.count
        }
        return Dictionary(uniqueKeysWithValues: result.map { ($0.0, Money(paise: $0.1)) })
    }
}
