import SwiftUI

/// A preset chooser that opens a searchable popover -- a plain Picker is
/// unusable with 1000+ presets. Shows the current selection; click to open a
/// filterable, folder-grouped list.
struct PresetPickerButton: View {
    let current: AvailablePreset?
    let presets: [AvailablePreset]
    let onSelect: (AvailablePreset?) -> Void

    @State private var isOpen = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack {
                Text(current?.name ?? "None")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(current == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            popover
        }
    }

    private var filtered: [AvailablePreset] {
        guard !query.isEmpty else { return presets }
        return presets.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.folder.localizedCaseInsensitiveContains(query)
        }
    }

    /// Preserves the incoming (already prioritized) order while grouping into
    /// contiguous folder sections.
    private var grouped: [(folder: String, presets: [AvailablePreset])] {
        var result: [(String, [AvailablePreset])] = []
        for preset in filtered {
            if let last = result.last, last.0 == preset.folder {
                result[result.count - 1].1.append(preset)
            } else {
                result.append((preset.folder, [preset]))
            }
        }
        return result.map { (folder: $0.0, presets: $0.1) }
    }

    private var popover: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search presets", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            Divider()

            List {
                Button("None") {
                    onSelect(nil)
                    isOpen = false
                }
                .buttonStyle(.plain)

                ForEach(grouped, id: \.folder) { group in
                    Section(group.folder) {
                        ForEach(group.presets) { preset in
                            Button {
                                onSelect(preset)
                                isOpen = false
                            } label: {
                                HStack {
                                    Text(preset.name).lineLimit(1)
                                    Spacer()
                                    if preset == current {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 340, height: 420)
        .onAppear { searchFocused = true }
    }
}
