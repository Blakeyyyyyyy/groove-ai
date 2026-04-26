import Foundation
import SwiftData

@Model
final class GeneratedVideo {
    var id: String
    var dancePresetID: String
    var danceName: String
    var photoData: Data?
    var videoURL: String?
    var status: String // "generating", "completed", "failed"
    var createdAt: Date
    var completedAt: Date?
    var minutesRemaining: Int
    var userId: String?  // For syncing across reinstalls
    var selectedSubjectId: String?  // "woman" or "dog" — for demo video routing

    init(
        id: String = UUID().uuidString,
        dancePresetID: String,
        danceName: String,
        photoData: Data? = nil,
        videoURL: String? = nil,
        status: String = "generating",
        createdAt: Date = .now,
        completedAt: Date? = nil,
        minutesRemaining: Int = 10,
        userId: String? = nil,
        selectedSubjectId: String? = nil
    ) {
        self.id = id
        self.dancePresetID = dancePresetID
        self.danceName = danceName
        self.photoData = photoData
        self.videoURL = videoURL
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.minutesRemaining = minutesRemaining
        self.userId = userId
        self.selectedSubjectId = selectedSubjectId
    }
}
