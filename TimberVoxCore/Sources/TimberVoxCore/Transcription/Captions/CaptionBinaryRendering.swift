import Foundation

public extension CaptionRenderer {
  static func renderPDF(
    _ document: CaptionDocument,
    includeTimestamps: Bool = false,
    includeSpeakers: Bool = false
  ) -> Data {
    let lines = pdfLines(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
    var contentLines = ["BT", "/F1 11 Tf", "50 790 Td"]
    for (index, line) in lines.enumerated() {
      if index > 0 {
        contentLines.append("0 -15 Td")
      }
      contentLines.append("(\(escapePDF(line.trimmingCharacters(in: .whitespacesAndNewlines)))) Tj")
    }
    contentLines.append("ET")
    let stream = contentLines.joined(separator: "\n") + "\n"
    let objects = pdfObjects(stream: stream)
    return pdfData(objects: objects)
  }

  static func renderDOCX(
    _ document: CaptionDocument,
    includeTimestamps: Bool = false,
    includeSpeakers: Bool = false
  ) -> Data {
    let body = docxParagraphs(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
      .map { "<w:p><w:r><w:t xml:space=\"preserve\">\(escapeXML($0))</w:t></w:r></w:p>" }
      .joined()
    return ZipArchive.store(docxEntries(body: body))
  }
}

private func pdfObjects(stream: String) -> [String] {
  [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Length \(stream.utf8.count) >>\nstream\n\(stream)endstream",
  ]
}

private func pdfData(objects: [String]) -> Data {
  var pdf = "%PDF-1.4\n"
  var offsets: [Int] = [0]
  for (index, object) in objects.enumerated() {
    offsets.append(pdf.utf8.count)
    pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
  }
  let xrefOffset = pdf.utf8.count
  pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
  for offset in offsets.dropFirst() {
    pdf += "\(String(offset).leftPadded(to: 10, with: "0")) 00000 n \n"
  }
  pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n"
  return Data(pdf.utf8)
}

private func docxEntries(body: String) -> [ZipEntry] {
  [
    ZipEntry(
      name: "[Content_Types].xml",
      data: Data(
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """.utf8
      )
    ),
    ZipEntry(
      name: "_rels/.rels",
      data: Data(
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """.utf8
      )
    ),
    ZipEntry(
      name: "word/document.xml",
      data: Data(
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>\(body)<w:sectPr/></w:body>
        </w:document>
        """.utf8
      )
    ),
  ]
}

private func docxParagraphs(
  _ document: CaptionDocument,
  includeTimestamps: Bool,
  includeSpeakers: Bool
) -> [String] {
  CaptionRenderer.transcriptBlocks(
    document,
    includeTimestamps: includeTimestamps,
    includeSpeakers: includeSpeakers
  )
  .flatMap { block in
    if let header = block.header {
      return [header, block.text, ""]
    }
    return [block.text, ""]
  }
  .dropLastEmpty()
}

private func pdfLines(
  _ document: CaptionDocument,
  includeTimestamps: Bool,
  includeSpeakers: Bool
) -> [String] {
  docxParagraphs(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
    .joined(separator: "\n")
    .split(separator: "\n", omittingEmptySubsequences: false)
    .flatMap { wrapPDFLine(String($0)) }
}

private func wrapPDFLine(_ line: String, maxCharacters: Int = 86) -> [String] {
  guard line.count > maxCharacters else {
    return [line]
  }
  var lines: [String] = []
  var remaining = line[...]
  while remaining.count > maxCharacters {
    let end = remaining.index(remaining.startIndex, offsetBy: maxCharacters)
    lines.append(String(remaining[..<end]))
    remaining = remaining[end...]
  }
  if !remaining.isEmpty {
    lines.append(String(remaining))
  }
  return lines
}

private func escapeXML(_ value: String) -> String {
  value
    .replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "<", with: "&lt;")
    .replacingOccurrences(of: ">", with: "&gt;")
    .replacingOccurrences(of: "\"", with: "&quot;")
}

private func escapePDF(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "(", with: "\\(")
    .replacingOccurrences(of: ")", with: "\\)")
}

private struct ZipEntry {
  let name: String
  let data: Data
}

private enum ZipArchive {
  static func store(_ entries: [ZipEntry]) -> Data {
    var archive = Data()
    var centralDirectory = Data()
    for entry in entries {
      append(entry: entry, to: &archive, centralDirectory: &centralDirectory)
    }

    let centralDirectoryOffset = UInt32(truncatingIfNeeded: archive.count)
    let centralDirectorySize = UInt32(truncatingIfNeeded: centralDirectory.count)
    archive.append(centralDirectory)
    archive.appendUInt32LE(0x0605_4b50)
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(UInt16(truncatingIfNeeded: entries.count))
    archive.appendUInt16LE(UInt16(truncatingIfNeeded: entries.count))
    archive.appendUInt32LE(centralDirectorySize)
    archive.appendUInt32LE(centralDirectoryOffset)
    archive.appendUInt16LE(0)
    return archive
  }

  private static func append(entry: ZipEntry, to archive: inout Data, centralDirectory: inout Data) {
    let offset = UInt32(truncatingIfNeeded: archive.count)
    let name = Data(entry.name.utf8)
    let crc = CRC32.checksum(entry.data)

    archive.appendLocalHeader(name: name, data: entry.data, crc: crc)
    centralDirectory.appendCentralDirectory(name: name, data: entry.data, crc: crc, offset: offset)
  }
}

private enum CRC32 {
  private static let table: [UInt32] = (0..<256).map { value in
    var crc = UInt32(value)
    for _ in 0..<8 {
      if crc & 1 == 1 {
        crc = 0xedb8_8320 ^ (crc >> 1)
      } else {
        crc >>= 1
      }
    }
    return crc
  }

  static func checksum(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffff_ffff
    for byte in data {
      let index = Int((crc ^ UInt32(byte)) & 0xff)
      crc = table[index] ^ (crc >> 8)
    }
    return crc ^ 0xffff_ffff
  }
}

private extension Data {
  mutating func appendLocalHeader(name: Data, data: Data, crc: UInt32) {
    appendUInt32LE(0x0403_4b50)
    appendUInt16LE(20)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt32LE(crc)
    appendUInt32LE(UInt32(truncatingIfNeeded: data.count))
    appendUInt32LE(UInt32(truncatingIfNeeded: data.count))
    appendUInt16LE(UInt16(truncatingIfNeeded: name.count))
    appendUInt16LE(0)
    append(name)
    append(data)
  }

  mutating func appendCentralDirectory(name: Data, data: Data, crc: UInt32, offset: UInt32) {
    appendUInt32LE(0x0201_4b50)
    appendUInt16LE(20)
    appendUInt16LE(20)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt32LE(crc)
    appendUInt32LE(UInt32(truncatingIfNeeded: data.count))
    appendUInt32LE(UInt32(truncatingIfNeeded: data.count))
    appendUInt16LE(UInt16(truncatingIfNeeded: name.count))
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt16LE(0)
    appendUInt32LE(0)
    appendUInt32LE(offset)
    append(name)
  }

  mutating func appendUInt16LE(_ value: UInt16) {
    append(UInt8(value & 0xff))
    append(UInt8((value >> 8) & 0xff))
  }

  mutating func appendUInt32LE(_ value: UInt32) {
    append(UInt8(value & 0xff))
    append(UInt8((value >> 8) & 0xff))
    append(UInt8((value >> 16) & 0xff))
    append(UInt8((value >> 24) & 0xff))
  }
}

private extension Array where Element == String {
  func dropLastEmpty() -> [String] {
    var values = self
    while values.last?.isEmpty == true {
      values.removeLast()
    }
    return values
  }
}

private extension String {
  func leftPadded(to length: Int, with character: Character) -> String {
    if count >= length {
      return self
    }
    return String(repeating: String(character), count: length - count) + self
  }
}
