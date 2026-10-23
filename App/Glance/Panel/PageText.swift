import AppKit

extension NSAttributedString.Key {
  /// Marks the text of a heading paragraph, which has no marker glyph.
  static let glanceHeading = NSAttributedString.Key("glanceHeading")
}

enum NoteKind: Int {
  case plain, checklist, bullet, heading
}

/// Converts between a page's markdown lines and the editor's text: one paragraph per line.
/// `- [ ] ` shows as "☐ ", `- [x] ` as "☑ " (struck through), `- ` as "• ", `### ` as a bold
/// paragraph, and anything else as plain text. Every conversion is lossless.
enum PageText {
  static let size: CGFloat = 13

  /// Markdown prefix and glyph, most specific first. `[X]` and `[-]` read as crossed out and save as `[x]`.
  private static let prefixes: [(markdown: String, glyph: String)] = [
    ("- [ ] ", "☐ "), ("- [x] ", "☑ "), ("- [X] ", "☑ "), ("- [-] ", "☑ "), ("- ", "• "),
  ]

  static func font(bold: Bool) -> NSFont {
    NSFont(name: bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
      ?? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
  }

  static var bodyAttributes: [NSAttributedString.Key: Any] {
    [.font: font(bold: false), .foregroundColor: NSColor.labelColor]
  }

  static var headingAttributes: [NSAttributedString.Key: Any] {
    [.font: font(bold: true), .foregroundColor: NSColor.labelColor, .glanceHeading: true]
  }

  /// The marker at the start of a paragraph, if any: its kind and length in UTF-16 units.
  static func marker(in line: String) -> (kind: NoteKind, length: Int)? {
    if line.hasPrefix("☐ ") { return (.checklist, 2) }
    if line.hasPrefix("☑ ") { return (.checklist, 2) }
    if line.hasPrefix("• ") { return (.bullet, 2) }
    return nil
  }

  static func display(_ line: String) -> (text: String, heading: Bool) {
    if line.hasPrefix("### "), line.count > 4 { return (String(line.dropFirst(4)), true) }
    for (markdown, glyph) in prefixes where line.hasPrefix(markdown) {
      return (glyph + line.dropFirst(markdown.count), false)
    }
    return (line, false)
  }

  private static func markdown(_ paragraph: String, heading: Bool) -> String {
    if heading { return "### " + paragraph }
    for (markdown, glyph) in [("- [ ] ", "☐ "), ("- [x] ", "☑ "), ("- ", "• ")]
    where paragraph.hasPrefix(glyph) {
      return markdown + paragraph.dropFirst(glyph.count)
    }
    return paragraph
  }

  static func lines(from text: NSAttributedString) -> [String] {
    guard text.length > 0 else { return [] }
    var location = 0
    return text.string.components(separatedBy: "\n").map { paragraph in
      let length = paragraph.utf16.count
      defer { location += length + 1 }
      let heading = length > 0 && heading(in: text, NSRange(location: location, length: length))
      return markdown(paragraph, heading: heading)
    }
  }

  static func attributed(from lines: [String]) -> NSAttributedString {
    let shown = lines.map(display)
    let text = NSMutableAttributedString(string: shown.map(\.text).joined(separator: "\n"))
    var location = 0
    for item in shown {
      let length = item.text.utf16.count
      if item.heading {
        text.addAttribute(
          .glanceHeading, value: true, range: NSRange(location: location, length: length))
      }
      location += length + 1
    }
    restyle(text)
    return text
  }

  static func doneCount(lines: [String]) -> Int {
    lines.count { display($0).text.hasPrefix("☑ ") }
  }

  private static func heading(in text: NSAttributedString, _ range: NSRange) -> Bool {
    var found = false
    text.enumerateAttribute(.glanceHeading, in: range) { value, _, stop in
      if value != nil {
        found = true
        stop.pointee = true
      }
    }
    return found
  }

  private static let markerIndent: CGFloat = ("☐ " as NSString)
    .size(withAttributes: [.font: font(bold: false)]).width

  /// Derives every paragraph's look from its text: heading, marker, done, and date tokens.
  static func restyle(_ text: NSMutableAttributedString) {
    let string = text.string as NSString
    var location = 0
    for paragraph in text.string.components(separatedBy: "\n") {
      let length = paragraph.utf16.count
      let start = location
      let content = NSRange(location: start, length: length)
      let whole = NSRange(location: start, length: min(length + 1, string.length - start))
      location += length + 1
      guard whole.length > 0 else { continue }
      let isHeading = heading(in: text, content)
      let marker = marker(in: paragraph)
      let done = paragraph.hasPrefix("☑ ")
      let style = NSMutableParagraphStyle()
      if marker != nil { style.headIndent = markerIndent }
      if isHeading { style.paragraphSpacingBefore = 8 }
      var attributes = isHeading ? headingAttributes : bodyAttributes
      attributes[.paragraphStyle] = style
      if done {
        attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        attributes[.foregroundColor] = NSColor.secondaryLabelColor
      }
      text.setAttributes(attributes, range: whole)
      if !isHeading { text.removeAttribute(.glanceHeading, range: whole) }
      if marker?.kind == .checklist,
        let token = [" 📅 ", " ✅ ", " 🤖 "].compactMap({
          (paragraph as NSString).range(of: $0).location
        })
        .filter({ $0 != NSNotFound }).min()
      {
        text.addAttribute(
          .foregroundColor, value: NSColor.secondaryLabelColor,
          range: NSRange(location: start + token, length: length - token))
      }
    }
  }
}
