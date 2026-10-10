import SwiftUI

/// Куда докрутить `HTScroll`: id блока (`.id(...)` или `htScrollAnchor`) и точка выравнивания.
public struct HTScrollTarget: Hashable {
    public let id: AnyHashable
    public let anchor: UnitPoint
    public init(_ id: AnyHashable, anchor: UnitPoint = .center) { self.id = id; self.anchor = anchor }
}

/// Состояние прокрутки для каркаса экрана: сдвинут ли контент и где верх области прокрутки (в окне).
/// `HTScreen` по нему показывает подложку с волосяной линией под строкой состояния.
struct HTScrollEdge: Equatable {
    var scrolled = false
    var top: CGFloat = 0
    /// Сдвиг контента от начального положения (pt); для компактной шапки оплаты.
    var offset: CGFloat = 0
}

struct HTScrollEdgeKey: PreferenceKey {
    static let defaultValue = HTScrollEdge()
    static func reduce(value: inout HTScrollEdge, nextValue: () -> HTScrollEdge) {
        let next = nextValue()
        if next.scrolled { value = next }
    }
}

/// Вертикальная прокрутка, совместимая со снапшотами.
/// interactive: обычный ScrollView. snapshot: тот же контент в VStack, выровненный по верху
/// (ImageRenderer не рисует содержимое ScrollView). Лишнее обрезается рамкой экрана,
/// либо рендерится целиком в режиме «full» (высота = идеальной высоте контента).
public struct HTScroll<Content: View>: View {
    @Environment(\.htRenderMode) private var mode
    @Environment(\.htSnapshotFullHeight) private var fullHeight
    @Environment(\.htReduceMotion) private var reduceMotion
    @State private var edge = HTScrollEdge()
    let target: HTScrollTarget?
    let animation: Animation
    let content: Content

    /// - Parameters:
    ///   - scrollTo: блок, к которому прокрутить при появлении и при каждой смене цели.
    ///   - animation: кривая докрутки (в оплате — `calm`).
    public init(scrollTo target: HTScrollTarget? = nil, animation: Animation = HTMotion.calm,
                @ViewBuilder content: () -> Content) {
        self.target = target; self.animation = animation; self.content = content()
    }

    public var body: some View {
        switch mode {
        case .interactive:
            ScrollViewReader { proxy in
                // VStack(spacing: 0), как в снапшоте: без него ScrollView кладёт блоки через 8 pt по умолчанию.
                ScrollView(.vertical, showsIndicators: false) { VStack(spacing: 0) { content } }
                    .scrollDismissesKeyboard(.interactively)
                    .htTrackScrollEdge($edge)
                    .preference(key: HTScrollEdgeKey.self, value: edge)
                    .onAppear {
                        guard let target else { return }
                        // Раскладка ScrollView готова только на следующем проходе.
                        DispatchQueue.main.async { proxy.scrollTo(target.id, anchor: target.anchor) }
                    }
                    .onChange(of: target) { _, new in
                        guard let new else { return }
                        // Следующий проход: вставленный блок уже разложен, прокрутка считает новую высоту.
                        // Анимация идёт одновременно с раскрытием блока.
                        DispatchQueue.main.async {
                            withAnimation(reduceMotion ? nil : animation) { proxy.scrollTo(new.id, anchor: new.anchor) }
                        }
                    }
            }
        case .snapshot where fullHeight:
            // Высота = идеальная высота контента (для *-full.png).
            VStack(spacing: 0) { content }
        case .snapshot:
            // Занимаем ровно предложенное место; контент прижат к верху и обрезан снизу,
            // как у ScrollView в начальной позиции.
            Color.clear
                .overlay(alignment: .top) {
                    VStack(spacing: 0) { content }.fixedSize(horizontal: false, vertical: true)
                }
                .clipped()
        }
    }
}

private extension View {
    /// Сдвиг контента (iOS 18+ / macOS 15+) и верх области прокрутки в окне. На iOS 17 линии под шапкой нет.
    @ViewBuilder
    func htTrackScrollEdge(_ edge: Binding<HTScrollEdge>) -> some View {
        let tracked = onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { edge.wrappedValue.top = $0 }
        if #available(iOS 18, macOS 15, *) {
            tracked.onScrollGeometryChange(for: CGFloat.self) { geo in
                // Шаг 4 pt: предпочтение не пересчитывается на каждый пиксель прокрутки.
                ((geo.contentOffset.y + geo.contentInsets.top) / 4).rounded() * 4
            } action: { _, offset in
                edge.wrappedValue.offset = offset
                edge.wrappedValue.scrolled = offset > HTSize.hairline
            }
        } else {
            tracked
        }
    }
}

public extension View {
    /// Растягивает view вверх, пока прокрутку оттягивают вниз: вместо полосы фона над фото —
    /// то же фото, увеличенное от нижнего края. View должна стоять у верха прокрутки.
    func htStretchOnPull(height: CGFloat) -> some View {
        visualEffect { content, proxy in
            let pull = max(0, proxy.frame(in: .global).minY)
            return content.scaleEffect(1 + pull / height, anchor: .bottom)
        }
    }

    /// Якорь прокрутки с запасом: id получает прозрачная рамка, выходящая за границы view на `top`/`bottom`.
    /// `scrollTo(id, anchor: .bottom)` тогда ставит низ view на `bottom` выше края области прокрутки
    /// (над закреплённым баром, над клавиатурой) — без лишних отступов в раскладке.
    func htScrollAnchor(_ id: some Hashable, top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        background {
            Color.clear
                .id(id)
                .padding(EdgeInsets(top: -top, leading: 0, bottom: -bottom, trailing: 0))
                .allowsHitTesting(false)
        }
    }
}

/// Список карточек: в приложении ленивый, в снапшоте — обычный VStack
/// (ImageRenderer не раскладывает ленивые стеки вне ScrollView надёжно).
public struct HTLazyVStack<Content: View>: View {
    @Environment(\.htRenderMode) private var mode
    let spacing: CGFloat
    let content: Content
    public init(spacing: CGFloat, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }

    public var body: some View {
        switch mode {
        case .interactive: LazyVStack(spacing: spacing) { content }
        case .snapshot: VStack(spacing: spacing) { content }
        }
    }
}

/// Горизонтальная карусель. В snapshot — HStack, обрезанный по ширине экрана.
public struct HTHScroll<Content: View>: View {
    @Environment(\.htRenderMode) private var mode
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        switch mode {
        case .interactive:
            ScrollView(.horizontal, showsIndicators: false) { content }
        case .snapshot:
            HTOverflowLeading { content }.clipped()
        }
    }
}

/// Layout: занимает предложенную ширину, ребёнка кладёт по левому краю в его идеальную ширину
/// (излишек уходит за правый край). В отличие от fixedSize+frame не раздувает родителя.
struct HTOverflowLeading: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(.unspecified)
        return CGSize(width: proposal.width ?? ideal.width, height: ideal.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(at: bounds.origin, anchor: .topLeading, proposal: .unspecified)
    }
}
