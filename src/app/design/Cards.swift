import SwiftUI
import UIKit

/// The look from the approved mockups: grey page, white rounded cards, pill buttons.
enum Theme {
    static let background = adaptive(light: 0xF3F4F6, dark: 0x000000)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondary = adaptive(light: 0x6C6F78, dark: 0x9A9DA5)
    static let separator = adaptive(light: 0xE9EAEE, dark: 0x38383A)
    /// The inner tiles of a card and the selected segment.
    static let tile = adaptive(light: 0xF0F1F4, dark: 0x2C2C2E)
    static let selectedSegment = adaptive(light: 0xECEEF2, dark: 0x3A3A3C)
    static let greyButton = adaptive(light: 0xE9EAEE, dark: 0x2C2C2E)
    static let blue = adaptive(light: 0x0A84FF, dark: 0x0A84FF)
    static let green = adaptive(light: 0x0A8A37, dark: 0x30D158)
    static let orange = adaptive(light: 0xC75A00, dark: 0xFF9F0A)
    static let red = adaptive(light: 0xD92D20, dark: 0xFF453A)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1
        )
    }
}

/// A scrolling page of cards on the grey background.
struct CardScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 96)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// A white card with free content, like the Left to spend card.
struct CardPanel<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 11, y: 6)
    }
}

/// A white card of rows with a hairline between each.
struct CardGroup<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let header { GroupHeader(header) }
            rows
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.045), radius: 11, y: 6)
            if let footer {
                Text(footer).font(.footnote).foregroundStyle(Theme.secondary).padding(.horizontal, 18)
            }
        }
    }

    @ViewBuilder private var rows: some View {
        if #available(iOS 18.0, *) {
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                        if index > 0 { Rectangle().fill(Theme.separator).frame(height: 1).padding(.leading, 18) }
                        subview
                    }
                }
            }
        } else {
            VStack(spacing: 0) { content }
        }
    }
}

struct GroupHeader: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
            .padding(.horizontal, 18).padding(.top, 2)
    }
}

/// Small caps label above a big figure: "LEFT TO SPEND".
struct CardCaption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased()).font(.system(size: 12, weight: .semibold)).kerning(0.6).foregroundStyle(Theme.secondary)
    }
}

/// One row of a card group: title and optional subtitle on the left, anything on the right.
struct CardRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var titleColor: Color = .primary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(titleColor)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .modifier(RowPadding())
    }
}

extension CardRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, titleColor: Color = .primary) {
        self.init(title: title, subtitle: subtitle, titleColor: titleColor) { EmptyView() }
    }
}

/// The padding every row in a card group gets.
struct RowPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 18).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
    }
}

extension View {
    func rowPadding() -> some View { modifier(RowPadding()) }
}

/// A form row: the label on the left, the control on the right.
struct FieldRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: Control

    init(_ label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer(minLength: 8)
            control.foregroundStyle(Theme.secondary)
        }
        .rowPadding()
    }
}

/// A row that opens another screen, with the chevron the mockups use.
struct LinkRow<Destination: View>: View {
    let title: String
    var subtitle: String?
    var value: String = ""
    var identifier: String?
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink { destination } label: {
            CardRow(title: title, subtitle: subtitle) {
                Text(value).foregroundStyle(Theme.secondary).monospacedDigit()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? title)
    }
}

/// A tappable row with a chevron, for rows that open a sheet.
struct ButtonRow: View {
    let title: String
    var subtitle: String?
    var value: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CardRow(title: title, subtitle: subtitle) {
                Text(value).foregroundStyle(Theme.secondary).monospacedDigit()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The mockups' three-way switch inside a card: Spending, Upcoming, Savings.
struct PillSegments<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    var badges: [Value: Int] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button { selection = option.value } label: {
                    Text(option.title).font(.system(size: 15.5, weight: .semibold))
                        .overlay(alignment: .topTrailing) {
                            if let count = badges[option.value], count > 0 {
                                Text("\(count)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 5).frame(minWidth: 17, minHeight: 17)
                                    .background(Theme.red, in: Capsule()).offset(x: 14, y: -9)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(selection == option.value ? Theme.selectedSegment : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityValue(badges[option.value].map { $0 > 0 ? "\($0)" : "" } ?? "")
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(16)
            .background(Theme.blue.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

struct GreyButtonStyle: ButtonStyle {
    var tint: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16.5, weight: .semibold)).foregroundStyle(tint)
            .frame(maxWidth: .infinity).padding(15)
            .background(Theme.greyButton.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

/// The small blue "Add" and "Record" buttons inside rows.
struct AddPillStyle: ButtonStyle {
    var done = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .foregroundStyle(done ? Theme.green : Theme.blue)
            .padding(.horizontal, 13).frame(minHeight: 34)
            .background((done ? Theme.green : Theme.blue).opacity(configuration.isPressed ? 0.2 : 0.09), in: Capsule())
    }
}

/// A small coloured label: "Auto", "Pending", "Added".
struct StatusPill: View {
    enum Tone { case orange, green, blue, grey, red }

    let text: String
    var tone = Tone.grey

    private var colour: Color {
        switch tone {
        case .orange: Theme.orange
        case .green: Theme.green
        case .blue: Theme.blue
        case .grey: Theme.secondary
        case .red: Theme.red
        }
    }

    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(colour)
            .padding(.horizontal, 9).padding(.vertical, 2)
            .background(colour.opacity(0.12), in: Capsule())
    }
}

/// A round white button with a soft shadow, as in the mockups' top bars.
struct CircleIcon: View {
    let systemName: String
    var badge: Int = 0

    var body: some View {
        Image(systemName: systemName).font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(Theme.card, in: Circle())
            .shadow(color: .black.opacity(0.09), radius: 5, y: 2)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20)
                        .background(Theme.red, in: Capsule()).offset(x: 4, y: -4)
                }
            }
    }
}

/// The grey page behind every navigation bar, so the bar blends into the page.
extension View {
    func cardNavigation(_ title: String, large: Bool = false) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(large ? .large : .inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
    }
}
