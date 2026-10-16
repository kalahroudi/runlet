import SwiftUI
import RunLetCore

private struct ScrollMetrics: Equatable {
    var offset = 0.0
    var content = 0.0
}

private struct ScrollMetricsKey: PreferenceKey {
    static let defaultValue = ScrollMetrics()
    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) { value = nextValue() }
}

/// A vertical scroll view with no scrollbar. A 16 pt fade shows on an edge that has hidden content.
/// With `followsEnd` it keeps the newest content in view until the person scrolls up, and then offers
/// a "Jump to latest" button.
struct StyledScrollView<Content: View>: View {
    /// The colour behind the scroll view, which the fade blends into.
    var fade: Color
    var followsEnd = false
    @ViewBuilder var content: Content

    @State private var state = ScrollState(offset: 0, content: 0, viewport: 0)
    @State private var viewport = 0.0
    @State private var follower = ScrollFollower()
    private let space = "styledScroll"

    private func apply(_ new: ScrollState, _ proxy: ScrollViewProxy) {
        state = new
        guard followsEnd else { return }
        if follower.update(new) { proxy.scrollTo("end", anchor: .bottom) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            tracked(proxy)
            .overlay(alignment: .top) { edge(visible: state.hiddenAbove, from: .top) }
            .overlay(alignment: .bottom) { edge(visible: state.hiddenBelow, from: .bottom) }
            .overlay(alignment: .bottomTrailing) {
                if followsEnd && follower.showsJumpButton {
                    Button {
                        follower.jumpToLatest()
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("end", anchor: .bottom) }
                    } label: {
                        Label("Jump to latest", systemImage: "arrow.down")
                            .font(RLFont.body(12, .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .foregroundStyle(Color.white)
                            .background(Color.rlAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
        }
    }

    /// The scroll view, reporting where it is scrolled. macOS 15 has an API for it. On macOS 14 the position
    /// is read from the geometry of the content.
    @ViewBuilder private func tracked(_ proxy: ScrollViewProxy) -> some View {
        let scroll = ScrollView {
            VStack(spacing: 0) {
                content
                Color.clear.frame(height: 0).id("end")
            }
            .background(GeometryReader { geo in
                Color.clear.preference(key: ScrollMetricsKey.self, value: ScrollMetrics(
                    offset: -geo.frame(in: .named(space)).minY, content: geo.size.height))
            })
        }
        .coordinateSpace(name: space)
        .scrollIndicators(.hidden)
        if #available(macOS 15, *) {
            scroll.onScrollGeometryChange(for: ScrollState.self) { geo in
                ScrollState(offset: geo.contentOffset.y + geo.contentInsets.top,
                            content: geo.contentSize.height, viewport: geo.containerSize.height)
            } action: { _, new in
                apply(new, proxy)
            }
        } else {
            scroll
                .background(GeometryReader { geo in
                    Color.clear.onAppear { viewport = geo.size.height }
                        .onChange(of: geo.size.height) { _, new in viewport = new }
                })
                .onPreferenceChange(ScrollMetricsKey.self) { new in
                    apply(ScrollState(offset: new.offset, content: new.content, viewport: viewport), proxy)
                }
        }
    }

    private func edge(visible: Bool, from side: UnitPoint) -> some View {
        LinearGradient(colors: [fade, fade.opacity(0)], startPoint: side,
                       endPoint: side == .top ? .bottom : .top)
            .frame(height: 16)
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: visible)
            .allowsHitTesting(false)
    }
}
