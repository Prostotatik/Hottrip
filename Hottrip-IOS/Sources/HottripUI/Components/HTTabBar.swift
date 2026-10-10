import SwiftUI

public enum HTTab: String, CaseIterable, Identifiable, Sendable {
    case home, search, favorites, profile
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .home: "Главная"
        case .search: "Поиск"
        case .favorites: "Избранное"
        case .profile: "Профиль"
        }
    }
    var icon: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .favorites: "heart"
        case .profile: "person"
        }
    }
    /// У лупы нет `.fill`-варианта — активность передают цвет и подложка.
    var activeIcon: String { self == .search ? icon : icon + ".fill" }
}

/// Таб-бар (spec-iter07 §1.2, §5): плавающая стеклянная капсула 74 pt, r 30, поля 12, низ на 38 pt над краем.
/// На тёмной главной — тёмное стекло, активный пункт лаймом на мягкой подложке; на светлых экранах —
/// светлое стекло, активная иконка `ink` на лаймовом круге 36. Подложка переезжает между пунктами (P1-10).
public struct HTTabBar: View {
    public enum Tone { case dark, light }

    @Environment(\.htReduceMotion) private var reduceMotion
    @Namespace private var pill
    let selected: HTTab
    let tone: Tone
    let onSelect: (HTTab) -> Void

    public init(selected: HTTab, tone: Tone, onSelect: @escaping (HTTab) -> Void) {
        self.selected = selected; self.tone = tone; self.onSelect = onSelect
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: HTRadius.tabBar, style: .continuous)
        HStack(spacing: 0) {
            ForEach(HTTab.allCases) { tab in item(tab) }
        }
        .padding(.horizontal, HTSpace.s8)
        .frame(height: HTSize.tabBar)
        .background(.ultraThinMaterial, in: shape)
        .background(tone == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.72), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(tone == .dark ? 0.18 : 0.9), lineWidth: HTSize.hairline))
        .environment(\.colorScheme, tone == .dark ? .dark : .light)
        .shadow(color: HTColor.ink.opacity(tone == .dark ? 0 : 0.08), radius: 14, x: 0, y: 8)
        .htAnimation(HTMotion.dot, value: selected, reduceMotion: reduceMotion)
        .sensoryFeedback(.selection, trigger: selected)
        .padding(.horizontal, HTSize.tabBarInset)
    }

    private func item(_ tab: HTTab) -> some View {
        let isOn = tab == selected
        return Button { onSelect(tab) } label: {
            VStack(spacing: HTSpace.s4) {
                Image(systemName: isOn ? tab.activeIcon : tab.icon)
                    .font(.system(size: tone == .light && isOn ? 18 : HTIcon.tab - 2, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(tint(isOn))
                    .frame(width: HTSize.tabPill, height: HTSize.tabPill)
                    .background {
                        if isOn && tone == .light {
                            Circle().fill(HTColor.lime).htMatchedGeometry(id: "tabPill", in: pill, enabled: !reduceMotion)
                        }
                    }
                Text(tab.title)
                    .font(.system(size: 11, weight: isOn ? .semibold : .medium))
                    .foregroundStyle(tint(isOn))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: HTSize.tabBar - HTSpace.s12)
            .background {
                if isOn && tone == .dark {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .htMatchedGeometry(id: "tabPill", in: pill, enabled: !reduceMotion)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }

    private func tint(_ isOn: Bool) -> Color {
        switch tone {
        case .dark: isOn ? HTColor.lime : .white.opacity(0.6)
        case .light: isOn ? HTColor.ink : HTColor.ink3
        }
    }
}
