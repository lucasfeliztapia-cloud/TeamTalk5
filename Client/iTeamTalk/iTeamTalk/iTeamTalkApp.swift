import SwiftUI

@main
struct iTeamTalkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serverListModel = ServerListModel()
    @StateObject private var appearance = AppearanceModel.shared

    var body: some Scene {
        WindowGroup {
            ServerListView(model: serverListModel)
                .tint(appearance.interfaceColor)
                .dynamicTypeSize(appearance.dynamicTypeRange)
                .preferredColorScheme(appearance.colorScheme)
                .modifier(FontDesignModifier(design: appearance.fontDesign.design))
        }
    }
}
