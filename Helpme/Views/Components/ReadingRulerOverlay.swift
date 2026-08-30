import SwiftUI
public enum ReadingRuler {
    public static func clampedOffset(
        start: CGFloat,
        translation: CGFloat,
        containerHeight: CGFloat,
        rulerHeight: CGFloat
    ) -> CGFloat {
        let maxOffset = max(0, containerHeight - rulerHeight)
        return min(max(0, start + translation), maxOffset)
    }
    public static let keyboardStep: CGFloat = 24
}
public struct ReadingRulerOverlay: View {
    @Binding public var offsetY: CGFloat
    public let height: Double
    @State private var dragAnchor: CGFloat? = nil
    public init(offsetY: Binding<CGFloat>, height: Double = 48.0) {
        self._offsetY = offsetY
        self.height = height
    }
    public var body: some View {
        GeometryReader { proxy in
            let rulerHeight = CGFloat(height)
            let containerHeight = proxy.size.height

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .frame(height: max(0, offsetY))
                    .allowsHitTesting(false)
                Rectangle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(height: rulerHeight)
                    .overlay(
                        VStack {
                            Divider().background(Color.orange.opacity(0.8))
                            Spacer()
                            Divider().background(Color.orange.opacity(0.8))
                        }
                    )
                    .overlay(alignment: .trailing) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.9))
                            .padding(.trailing, 8)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .offset(y: offsetY)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let anchor = dragAnchor ?? offsetY
                                if dragAnchor == nil { dragAnchor = anchor }
                                offsetY = ReadingRuler.clampedOffset(
                                    start: anchor,
                                    translation: value.translation.height,
                                    containerHeight: containerHeight,
                                    rulerHeight: rulerHeight
                                )
                            }
                            .onEnded { _ in dragAnchor = nil }
                    )
                    .draggableCursor()
                    .accessibilityElement()
                    .accessibilityLabel("Righello di lettura")
                    .accessibilityHint("Trascinalo, o usa le frecce, per incorniciare la riga che stai leggendo")
                    .accessibilityAdjustableAction { direction in
                        let step: CGFloat = direction == .increment
                            ? ReadingRuler.keyboardStep
                            : -ReadingRuler.keyboardStep
                        offsetY = ReadingRuler.clampedOffset(
                            start: offsetY,
                            translation: step,
                            containerHeight: containerHeight,
                            rulerHeight: rulerHeight
                        )
                    }
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .frame(height: max(0, containerHeight - offsetY - rulerHeight))
                    .offset(y: offsetY + rulerHeight)
                    .allowsHitTesting(false)
            }
            .onChange(of: containerHeight) { _, newHeight in
                offsetY = ReadingRuler.clampedOffset(
                    start: offsetY,
                    translation: 0,
                    containerHeight: newHeight,
                    rulerHeight: rulerHeight
                )
            }
        }
    }
}
