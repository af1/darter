import Combine
import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig

    /// One entry per binding slot whose key was just stolen by an
    /// assignment elsewhere; the fresh UUID retriggers the red fade-out
    /// flash in that slot's KeyCaptureField. Slot ids: "<paramName>.dec",
    /// "<paramName>.inc", "tool.<toolName>".
    @Published private(set) var stolenPulses: [String: UUID] = [:]

    /// Develop presets read from the file the plugin exports. Populated on
    /// init and refreshed when the user asks Lightroom to re-export.
    @Published private(set) var availablePresets: [AvailablePreset] = []
    @Published private(set) var isRefreshingPresets = false

    private weak var coordinator: Coordinator?

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        self.config = coordinator.config
        self.availablePresets = PresetStore.load()
    }

    func commit() {
        coordinator?.updateConfig(config)
    }

    func importSettings() {
        coordinator?.importSettings()
    }

    func exportSettings() {
        coordinator?.exportSettings()
    }

    func loadStarterProfile(_ profile: StarterProfile) {
        coordinator?.loadStarterProfile(profile)
    }

    private func index(of slider: SliderBinding) -> Int? {
        config.sliders.firstIndex(where: { $0.id == slider.id })
    }

    func setRelativeAmount(_ amount: Double, for slider: SliderBinding) {
        guard let i = index(of: slider) else { return }
        config.sliders[i].relativeAmount = amount
        commit()
    }

    func setAmount(_ amount: Double, for slider: SliderBinding) {
        guard let i = index(of: slider) else { return }
        config.sliders[i].amount = amount
        commit()
    }

    func setDecreaseKey(_ key: KeyBinding?, for slider: SliderBinding) {
        guard let i = index(of: slider) else { return }
        if let key { stealKey(key, except: Self.decSlot(slider)) }
        config.sliders[i].decreaseKey = key
        commit()
    }

    func setIncreaseKey(_ key: KeyBinding?, for slider: SliderBinding) {
        guard let i = index(of: slider) else { return }
        if let key { stealKey(key, except: Self.incSlot(slider)) }
        config.sliders[i].increaseKey = key
        commit()
    }

    private func index(of tool: ToolBinding) -> Int? {
        config.tools.firstIndex(where: { $0.id == tool.id })
    }

    func setToolKey(_ key: KeyBinding?, for tool: ToolBinding) {
        guard let i = index(of: tool) else { return }
        if let key { stealKey(key, except: Self.toolSlot(tool)) }
        config.tools[i].key = key
        commit()
    }

    // MARK: Preset slots

    func setPreset(_ preset: AvailablePreset?, forDigit digit: Int) {
        guard let i = config.presetSlots.firstIndex(where: { $0.digit == digit }) else { return }
        config.presetSlots[i].folder = preset?.folder
        config.presetSlots[i].presetName = preset?.name
        commit()
    }

    /// Ask Lightroom (via the plugin) to re-export the preset list, then
    /// re-read the file after a short delay to let the plugin write it.
    /// Fire-and-forget URL means we can't know exactly when it's done, so we
    /// poll the file a couple of times.
    func refreshPresetsFromLightroom() {
        isRefreshingPresets = true
        LightroomURLSender.requestPresetList()

        let deadlines: [Double] = [0.6, 1.2, 2.0]
        for delay in deadlines {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.availablePresets = PresetStore.load()
                if delay == deadlines.last { self.isRefreshingPresets = false }
            }
        }
    }

    static func decSlot(_ slider: SliderBinding) -> String { "\(slider.paramName).dec" }
    static func incSlot(_ slider: SliderBinding) -> String { "\(slider.paramName).inc" }
    static func toolSlot(_ tool: ToolBinding) -> String { "tool.\(tool.toolName)" }

    /// Last assignment wins: binding a key clears it from wherever else it
    /// was bound, so a combination can never trigger two actions.
    ///
    /// Compares the FULL binding (key + required modifiers), so "L" and
    /// "Shift+L" can coexist -- HotkeyMatcher resolves those by preferring
    /// the most specific match, the same way Tab / Shift+Tab already works.
    /// (An earlier version compared key code alone, back when a loose
    /// binding matched regardless of held modifiers and the two really were
    /// ambiguous; strict modifier matching has since removed that.)
    ///
    /// Each cleared slot gets a stolen pulse so its field flashes red.
    /// `except` is the slot being assigned -- rebinding a key to the field
    /// that already holds it shouldn't flash that same field.
    private func stealKey(_ key: KeyBinding, except: String) {
        for i in config.sliders.indices {
            let dec = Self.decSlot(config.sliders[i])
            if dec != except, config.sliders[i].decreaseKey == key {
                config.sliders[i].decreaseKey = nil
                stolenPulses[dec] = UUID()
            }
            let inc = Self.incSlot(config.sliders[i])
            if inc != except, config.sliders[i].increaseKey == key {
                config.sliders[i].increaseKey = nil
                stolenPulses[inc] = UUID()
            }
        }
        for i in config.tools.indices {
            let slot = Self.toolSlot(config.tools[i])
            if slot != except, config.tools[i].key == key {
                config.tools[i].key = nil
                stolenPulses[slot] = UUID()
            }
        }
    }
}
