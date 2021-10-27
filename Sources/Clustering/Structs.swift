import Foundation
import NaturalLanguage

struct EntitiesInText {
    var entities = ["PersonalName": [String](), "PlaceName": [String](), "OrganizationName": [String]()]
}

public struct Page {
    public init(id: UUID, parentId: UUID? = nil, title: String? = nil, originalContent: [String]? = nil, cleanedContent: String? = nil) {
        self.id = id
        self.parentId = parentId
        self.title = title
        self.originalContent = originalContent
        self.cleanedContent = cleanedContent
    }

    var id: UUID
    var parentId: UUID?
    var title: String?
    var originalContent: [String]?
    var cleanedContent: String?
    var textEmbedding: [Double]?
    var entities: EntitiesInText?
    var language: NLLanguage?
    var entitiesInTitle: EntitiesInText?
    var attachedPages = [UUID]()
}

public struct ClusteringNote {
    public init(id: UUID, title: String? = nil, content: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
    }
    var id: UUID
    var title: String?
    var content: String?  // Text in the note.
                          // TODO: Should we save to source (copy-paste from a page, user input...)
    var textEmbedding: [Double]?
    var entities: EntitiesInText?
    var language: NLLanguage?
    var entitiesInTitle: EntitiesInText?
}
