import SwiftUI

/// Рамка телефона для снапшотов: статус-бар 9:41, Dynamic Island, home indicator, скругление.
/// В приложении не используется.
public struct HTDeviceChrome<Content: View>: View {
    let dark: Bool
    let content: Content
    public init(darkStatusBar: Bool = false, @ViewBuilder content: () -> Content) {
        self.dark = darkStatusBar; self.content = content()
    }

    public var body: some View {
        let fg: Color = dark ? .white : HTColor.ink
        content
            .frame(width: HTDevice.size.width, height: HTDevice.size.height)
            .overlay(alignment: .top) {
                ZStack {
                    HStack {
                        Text("9:41").font(.system(size: 17, weight: .semibold))
                            .frame(width: 110)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "cellularbars")
                            Image(systemName: "wifi")
                            Image(systemName: "battery.100")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 110)
                    }
                    .foregroundStyle(fg)
                    Capsule().fill(HTColor.Chrome.island).frame(width: 126, height: 37)
                }
                .padding(.top, 11)
                .frame(height: 54, alignment: .top)
            }
            .overlay(alignment: .bottom) {
                Capsule().fill(fg).frame(width: 139, height: 5).padding(.bottom, 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: HTDevice.cornerRadius, style: .continuous))
            .padding(10)
            .background(RoundedRectangle(cornerRadius: HTDevice.cornerRadius + 10, style: .continuous).fill(HTColor.Chrome.frame))
    }
}
