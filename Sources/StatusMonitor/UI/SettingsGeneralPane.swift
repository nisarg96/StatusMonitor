import StatusMonitorCore
import SwiftUI

/// The General page: appearance, startup, battery readings and the network counting options.
struct SettingsGeneralPane: View {
    @ObservedObject var settings: SettingsViewModel

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { settings.settings.appearance },
                    set: { settings.setAppearance($0) }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Startup") {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.opensAtLogin },
                    set: { settings.setOpensAtLogin($0) }
                ))
                if let error = settings.loginItemError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Battery details") {
                ForEach(BatteryDetail.allCases, id: \.self) { detail in
                    Toggle(Self.batteryDetailName(detail), isOn: Binding(
                        get: { settings.settings.isBatteryDetailShown(detail) },
                        set: { settings.setBatteryDetail(detail, shown: $0) }
                    ))
                }
            }

            Section("Network") {
                Toggle("Include loopback (lo0)", isOn: Binding(
                    get: { settings.settings.includeLoopback },
                    set: { settings.setIncludeLoopback($0) }
                ))
                TextField("Interfaces, e.g. en0, utun3 (blank = all)", text: $settings.interfaceText)
            }
        }
        .formStyle(.grouped)
    }

    private static func batteryDetailName(_ detail: BatteryDetail) -> String {
        switch detail {
        case .charge: return "Charge row"
        case .powerFlow: return "Charging / discharging watts"
        case .menuBarCharge: return "Battery % in menu bar"
        case .health: return "Health"
        case .cycles: return "Cycle count"
        case .powerState: return "Power state"
        case .lowPowerMode: return "Low Power Mode"
        case .timeRemaining: return "Time remaining"
        }
    }
}
