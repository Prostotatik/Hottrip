import SwiftUI

/// Профиль (spec-iter07 §5.4): аватар-инициалы на лайме, тёмная карточка «поездки / бонусы»
/// (перекличка с главной), три группы настроек.
public struct ProfileScreen: View {
    @Environment(\.htSafeArea) private var safe
    @State private var hotAlerts = true
    let user: UserProfile

    public init(user: UserProfile) { self.user = user }

    public var body: some View {
        HTScreen {
            HTScroll {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    stats.padding(.top, HTSpace.s24)
                    group {
                        row("Мои поездки", icon: "suitcase", detail: "\(user.activeTrips) \(HTFormat.plural(user.activeTrips, "активная", "активные", "активных"))")
                        row("Способы оплаты", icon: "creditcard")
                        row("Документы и паспорта", icon: "person.text.rectangle", last: true)
                    }
                    .padding(.top, HTSpace.s24)
                    group {
                        HStack(spacing: HTSpace.s12) {
                            icon("flame")
                            Text("Новые горящие туры").htStyle(.body).foregroundStyle(HTColor.ink).lineLimit(1)
                            Spacer(minLength: 0)
                            HTSwitch(isOn: $hotAlerts, label: "Уведомления о горящих турах")
                        }
                        .padding(.horizontal, HTSpace.s16)
                        .frame(height: HTSize.settingsRow)
                        .overlay(alignment: .bottom) { HTHairline().padding(.leading, Self.hairlineInset) }
                        row("Язык", icon: "globe", detail: "Русский")
                        row("Валюта", icon: "banknote", detail: "UZS", last: true)
                    }
                    .padding(.top, HTSpace.s16)
                    group {
                        row("Поддержка в Telegram", icon: "paperplane")
                        row("О приложении", icon: "info.circle", detail: "0.1 · демо", last: true)
                    }
                    .padding(.top, HTSpace.s16)
                }
                .htScreenPadding()
                .padding(.top, safe.top + HTSpace.s16)
                .padding(.bottom, HTSize.tabBarClearance + HTSpace.s24)
            }
        }
    }

    private var header: some View {
        HStack(spacing: HTSpace.s16) {
            Text(user.initials)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(HTColor.onLime)
                .frame(width: HTSize.avatar, height: HTSize.avatar)
                .background(HTColor.lime, in: Circle())
            VStack(alignment: .leading, spacing: HTSpace.s2) {
                Text(user.name).htStyle(HTTextStyle(22, 26, .bold, tracking: -0.3)).foregroundStyle(HTColor.ink)
                Text(user.phone).htStyle(.bodyS).foregroundStyle(HTColor.ink2)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("Поездок") { Text("\(user.trips)").foregroundStyle(.white) }
            Color.white.opacity(0.14).frame(width: HTSize.hairline).padding(.vertical, HTSpace.s20)
            stat("Бонусы") { Text(HTFormat.uzs(user.bonuses)).foregroundStyle(HTColor.lime).lineLimit(1).minimumScaleFactor(0.7) }
        }
        .frame(height: HTSize.profileStats)
        .background(LinearGradient(colors: [HTColor.night700, HTColor.night900], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: HTRadius.banner, style: .continuous))
    }

    private func stat<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: HTSpace.s4) {
            Text(label).htStyle(.caption).foregroundStyle(.white.opacity(0.7))
            value().htStyle(.price)
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HTSpace.s20)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }.htCard(radius: HTRadius.summary)
    }

    /// Разделитель строк начинается под текстом, а не под иконкой.
    private static let hairlineInset = HTSpace.s16 + HTSize.settingsIcon + HTSpace.s12

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: HTIcon.small, weight: .medium))
            .foregroundStyle(HTColor.ink)
            .frame(width: HTSize.settingsIcon, height: HTSize.settingsIcon)
            .background(HTColor.canvasTop, in: Circle())
    }

    private func row(_ title: String, icon name: String, detail: String? = nil, last: Bool = false) -> some View {
        Button {} label: {
            HStack(spacing: HTSpace.s12) {
                icon(name)
                Text(title).htStyle(.body).foregroundStyle(HTColor.ink)
                Spacer()
                if let detail { Text(detail).htStyle(.bodyS).foregroundStyle(HTColor.ink3) }
                Image(systemName: "chevron.right").font(.system(size: HTIcon.micro, weight: .semibold)).foregroundStyle(HTColor.ink3)
            }
            .padding(.horizontal, HTSpace.s16)
            .frame(height: HTSize.settingsRow)
            .overlay(alignment: .bottom) { if !last { HTHairline().padding(.leading, Self.hairlineInset) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
