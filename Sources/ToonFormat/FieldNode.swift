import Foundation

/// One entry of the field list of a tabular header.
///
/// TOON specification § 9.3 lets a uniform nested-object column collapse into
/// the header, while the rows stay flat:
///
/// ```toon
/// orders[2]{id,customer{name,country},total}:
///   1,Ada,DK,99
///   2,Bob,UK,149
/// ```
///
/// The nesting has no depth cap. A row carries one cell per leaf, in
/// depth-first order, so `1,Ada,DK,99` fills `id`, `customer.name`,
/// `customer.country` and `total`.
struct FieldNode: Hashable {
    let name: String
    /// `nil` for a leaf, a list for a nested field group.
    let children: [FieldNode]?

    init(name: String, children: [FieldNode]? = nil) {
        self.name = name
        self.children = children
    }

    var isLeaf: Bool { children == nil }
}

extension Array where Element == FieldNode {
    /// The number of cells that one row carries.
    ///
    /// The width check of § 14.1 uses this count, not the number of entries of
    /// the field list.
    var leafCount: Int {
        reduce(0) { total, field in
            total + (field.children?.leafCount ?? 1)
        }
    }

    /// The first name that repeats inside one level of the list.
    ///
    /// § 9.3 states that names repeated at different levels of nesting are not
    /// duplicates, so `{x,n{x}}` is well-formed. The check therefore starts a
    /// new set of seen names for every level.
    ///
    /// Two names are the same name only when their Unicode scalar sequences
    /// are equal. § 16 gives that rule to a field name as it gives it to a
    /// key, so the set holds ``ScalarKey`` and not `String`.
    func firstDuplicateName() -> String? {
        var seen = Set<ScalarKey>()
        for field in self {
            if !seen.insert(ScalarKey(field.name)).inserted {
                return field.name
            }
            if let nested = field.children?.firstDuplicateName() {
                return nested
            }
        }
        return nil
    }
}
