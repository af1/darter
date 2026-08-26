import Foundation

/// How held ← / → photo navigation is handled.
///
/// Background: holding an arrow in Lightroom can keep scrolling for many
/// seconds after release (20s measured). This was verified to be Lightroom's
/// own behavior, NOT something Darter causes -- it reproduces identically
/// with Darter quit, and with our event tap provably suspended (zero
/// events reaching it during the hold). Lightroom queues navigation from its
/// internal key-repeat faster than it can render uncached previews, and works
/// through the backlog after the key is up. Building Standard-Sized Previews
/// in Lightroom reduces it at the source.
enum ArrowNavMode: String, Codable, CaseIterable, Equatable {
    /// Suspend our event tap for the duration of the hold, so Lightroom sees
    /// exactly the event stream it would with Darter not running: native
    /// repeat speed, and native overscroll along with it.
    case native

    /// Swallow held arrows and drive LrSelection.nextPhoto/previousPhoto on
    /// our own timer at a configurable rate. Lightroom never sees a held key,
    /// so its internal repeat never starts and nothing can queue past the
    /// release -- the only mode that actually bounds the overscroll. Costs
    /// the native hold feel (fixed rate instead).
    case paced

    var displayName: String {
        switch self {
        case .native: return "Native"
        case .paced: return "Paced"
        }
    }
}
