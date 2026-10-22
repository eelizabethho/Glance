import Foundation
import GlanceCore
import Observation

/// The app's one view of `todo.md`. Every edit goes through `perform`.
@Observable final class AppState {
  static let defaultURL = URL.homeDirectory.appending(path: "workspace/notes-reminder/data/todo.md")

  private(set) var document: GlanceDocument
  private(set) var lastError: (any Error)?
  private let store: FileStore

  init(url: URL = defaultURL) {
    store = FileStore(url: url)
    do {
      document = try store.read().0
    } catch {
      document = MarkdownParser.parse("")
      lastError = error
    }
  }

  var todoCount: Int { Counts.todo(document) }
  var dueCount: Int { Counts.dueTodayOrOverdue(document, now: .now) }

  /// Applies `edit` to the latest file and shows the result. A thrown error leaves the file as is.
  func perform(_ edit: (inout GlanceDocument) throws -> Void) {
    do {
      document = try store.write { doc in
        try edit(&doc)
        return doc
      }
      lastError = nil
    } catch {
      lastError = error
    }
  }
}
