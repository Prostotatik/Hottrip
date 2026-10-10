import SwiftUI

/// Избранное (spec-iter07 §5.3): сегменты «Туры / Направления», подсказка о слежении за ценой,
/// строки туров с фото или сетка направлений; пустое состояние со звездой.
public struct FavoritesScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @State private var segment: Segment
    let tours: [Tour]

    public enum Segment: Hashable, Sendable { case tours, destinations }

    public init(tours: [Tour], segment: Segment = .tours) {
        self.tours = tours
        _segment = State(initialValue: segment)
    }

    private var destinations: [Destination] {
        tours.map(\.destination).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }

    public var body: some View {
        HTScreen {
            HTScroll {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Избранное").htStyle(.h1).foregroundStyle(HTColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    if tours.isEmpty {
                        HTEmptyState("Здесь пока пусто",
                                     message: "Нажмите на сердце в карточке тура — мы будем следить за ценой") {
                            HTPrimaryButton("Найти тур", arrow: true) { router.select(.search) }
                        }
                        .padding(.top, 120)
                    } else {
                        HTSegmented(selection: $segment, items: [
                            (.tours, "Туры · \(tours.count)"),
                            (.destinations, "Направления · \(destinations.count)"),
                        ])
                        .padding(.top, HTSpace.s16)
                        HStack(spacing: HTSpace.s8) {
                            Image(systemName: "bell").font(.system(size: HTIcon.small, weight: .medium))
                            Text("Сообщим, если цена упадёт").htStyle(.footnote)
                        }
                        .foregroundStyle(HTColor.ink2)
                        .padding(.top, HTSpace.s16)
                        Group {
                            switch segment {
                            case .tours:
                                VStack(spacing: HTSpace.s12) {
                                    ForEach(tours) { tour in FavoriteTourRow(tour: tour) { router.push(.tour(tour)) } }
                                }
                            case .destinations:
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(HTSize.destinationCard.width), spacing: HTSpace.s10), count: 3),
                                          alignment: .leading, spacing: HTSpace.s10) {
                                    ForEach(destinations) { d in
                                        let query = MockData.selectionQuery(d)
                                        DestinationCard(title: d.country, imageName: d.imageName, fromPrice: MockData.fromPrice(query)) {
                                            router.push(.results(query))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, HTSpace.s12)
                    }
                }
                .htScreenPadding()
                .padding(.top, safe.top + HTSpace.s16)
                .padding(.bottom, HTSize.tabBarClearance + HTSpace.s24)
            }
        }
    }
}

/// Сегмент-контрол h 40, r 20: фон `surface`, выбранный сегмент `ink` с белым текстом, переезжает.
struct HTSegmented<Value: Hashable>: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    @Namespace private var space
    @Binding var selection: Value
    let items: [(Value, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { value, title in
                let isOn = value == selection
                Button { withAnimation(reduceMotion ? nil : HTMotion.select) { selection = value } } label: {
                    Text(title)
                        .htStyle(.bodySMedium)
                        .foregroundStyle(isOn ? .white : HTColor.ink2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if isOn {
                                Capsule().fill(HTColor.ink)
                                    .htMatchedGeometry(id: "segment", in: space, enabled: !reduceMotion)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(height: HTSize.segmented)
        .htCard(radius: HTSize.segmented / 2)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
