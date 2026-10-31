public struct CategoryGroup: Equatable, Sendable {
    public let name: String
    public let subCategories: [String]
}

/// The categories a fresh install starts with.
public enum DefaultCategories {
    public static let tree: [CategoryGroup] = [
        CategoryGroup(name: "Home & Utilities", subCategories: [
            "Electric", "Gas", "Internet", "Mortgage", "Rent", "Home maintenance", "Utilities", "Cell phone",
        ]),
        CategoryGroup(name: "Food & Dining", subCategories: ["Restaurant", "Food delivery", "Coffee", "Alcohol"]),
        CategoryGroup(name: "Groceries", subCategories: ["Ration", "Milk", "Biscuits"]),
        CategoryGroup(name: "Health & Medical", subCategories: [
            "Medical", "Blood tests", "Skin & face", "Dental", "Personal care", "Fitness", "Supplements",
            "Vision", "Therapy", "Pharmacy", "Courses",
        ]),
        CategoryGroup(name: "Transport", subCategories: ["Ride share", "Train tickets", "Metro tickets", "Travel", "Flight tickets"]),
        CategoryGroup(name: "Vehicle", subCategories: ["Vehicle service", "Vehicle repairs", "Vehicle loan", "Parking"]),
        CategoryGroup(name: "Fuel", subCategories: []),
        CategoryGroup(name: "Insurance", subCategories: [
            "Health insurance - Me", "Health insurance - Mom", "Term life", "Vehicle insurance",
            "Home insurance", "Travel insurance",
        ]),
        CategoryGroup(name: "Entertainment & Movies", subCategories: []),
        CategoryGroup(name: "Personal", subCategories: []),
        CategoryGroup(name: "Family", subCategories: ["Family cash gifts"]),
        CategoryGroup(name: "Transfers", subCategories: []),
        CategoryGroup(name: "Lifestyle", subCategories: [
            "Subscriptions", "Vacation", "Concerts", "Charity", "Clothing", "Gifts", "Child care",
            "Night life", "Pets",
        ]),
        CategoryGroup(name: "Shopping - Needs", subCategories: []),
        CategoryGroup(name: "Shopping - Wants", subCategories: ["Perfumes"]),
        CategoryGroup(name: "Technology & Gadgets", subCategories: ["Courses"]),
        CategoryGroup(name: "Monthly Fixed Expenses", subCategories: []),
        CategoryGroup(name: "Annual Fixed Expenses", subCategories: []),
        CategoryGroup(name: "Trading account", subCategories: ["Money added", "Fees & charges"]),
        CategoryGroup(name: "Miscellaneous", subCategories: [
            "Special occasions", "Loan payment", "Credit card payment", "Bad expenses",
        ]),
    ]
}
