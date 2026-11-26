/// A memory clean preset. Standard runs one purge step. Extreme adds a memory pressure step and a second purge.
public enum CleanPreset: String, Codable, CaseIterable, Sendable {
    /// Purges inactive file-backed memory with a single `purge` step.
    case standard
    /// Runs `purge`, then `memory_pressure -l warn`, then a second `purge`.
    case extreme
}
