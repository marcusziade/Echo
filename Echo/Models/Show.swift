import Foundation
import GRDB

/// Basic Show model for database testing
struct Show: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var title: String

    static let databaseTableName = "shows"

    enum Columns: String, ColumnExpression {
        case id
        case title
    }

    init(id: Int64? = nil, title: String) {
        self.id = id
        self.title = title
    }
}
