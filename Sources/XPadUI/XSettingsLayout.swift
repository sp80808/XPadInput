import SwiftUI

/// Settings chrome that stays inside its parent instead of expanding past it.
///
/// macOS segmented pickers size to the sum of their labels. When that ideal
/// width exceeds the available space, fall back to a menu so the card, sheet,
/// or popover is never forced wider than the window.

struct XWidthSafePicker<SelectionValue: Hashable, Content: View>: View {
    var selection: Binding<SelectionValue>
    var label: String
    @ViewBuilder var content: Content

    init(
        _ label: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.selection = selection
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Picker(label, selection: selection) {
                content
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker(label, selection: selection) {
                content
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(label)
    }
}

/// Horizontal chrome that can scroll instead of clipping its first/last items.
struct XContainedHScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
        }
    }
}

extension View {
    /// Lets text and controls wrap inside settings cards instead of widening them.
    func xSettingsContained() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sheets and popovers grow with Dynamic Type instead of clipping at a fixed height.
    func xSettingsSheetSize(minWidth: CGFloat = 360, idealWidth: CGFloat = 440) -> some View {
        padding(24)
            .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: 560)
            .fixedSize(horizontal: false, vertical: true)
    }
}
