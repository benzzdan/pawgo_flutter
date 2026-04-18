import ActivityKit
import SwiftUI

/// ActivityAttributes for Pawgo walk Live Activities.
///
/// Static attributes are set when the activity starts and do not change.
/// ContentState contains the dynamic values that update throughout the walk.
struct PawgoWalkAttributes: ActivityAttributes {
    // MARK: - Static attributes (set once at start)

    /// Name of the walker performing the walk.
    var walkerName: String

    /// Name of the dog being walked.
    var dogName: String

    // MARK: - Dynamic content state

    struct ContentState: Codable, Hashable {
        /// Current stage of the walk (e.g. "walker_en_route", "walk_started", "walk_completed").
        var stage: String

        /// Minutes elapsed since the walk started.
        var elapsedMinutes: Int
    }
}
