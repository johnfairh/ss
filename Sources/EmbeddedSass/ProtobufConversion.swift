//
//  ProtobufConversion.swift
//  EmbeddedSass
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/main/LICENSE
//

// Helpers to shuffle data in and out of the protobuf types.

import Foundation

// MARK: PB -> Native

extension String {
    var nonEmptyString: String? {
        isEmpty ? nil : self
    }
}

extension Span {
    init(_ protobuf: Sass_EmbeddedProtocol_SourceSpan) {
        self = Self(text: protobuf.text.nonEmptyString,
                    url: protobuf.url.nonEmptyString,
                    start: Location(protobuf.start),
                    end: protobuf.hasEnd ? Location(protobuf.end) : nil,
                    context: protobuf.context.nonEmptyString)
    }
}

extension Span.Location {
    init(_ protobuf: Sass_EmbeddedProtocol_SourceSpan.SourceLocation) {
        self = Self(offset: Int(protobuf.offset),
                    line: Int(protobuf.line),
                    column: Int(protobuf.column))
    }
}

extension CompilerResults {
    init(_ protobuf: Sass_EmbeddedProtocol_OutboundMessage.CompileResponse.CompileSuccess,
         messages: [CompilerMessage]) {
        self = Self(css: protobuf.css,
                    sourceMap: protobuf.sourceMap.nonEmptyString,
                    messages: messages)
    }
}

extension CompilerError {
    init(_ protobuf: Sass_EmbeddedProtocol_OutboundMessage.CompileResponse.CompileFailure,
         messages: [CompilerMessage]) {
        self = Self(message: protobuf.message,
                    span: protobuf.hasSpan ? .init(protobuf.span) : nil,
                    stackTrace: protobuf.stackTrace.nonEmptyString,
                    messages: messages)
    }
}

extension CompilerMessage.Kind {
    init(_ type: Sass_EmbeddedProtocol_OutboundMessage.LogEvent.TypeEnum) throws {
        switch type {
        case .deprecationWarning: self = .deprecation
        case .warning: self = .warning
        case .debug: self = .debug
        default:
            throw ProtocolError("Unrecognized warning type \(type) from compiler")
        }
    }
}

extension CompilerMessage {
    init(_ protobuf: Sass_EmbeddedProtocol_OutboundMessage.LogEvent) throws {
        self = Self(kind: try Kind(protobuf.type),
                    message: protobuf.message,
                    span: protobuf.hasSpan ? .init(protobuf.span) : nil,
                    stackTrace: protobuf.stackTrace.nonEmptyString)
    }
}

// MARK: Native -> PB

extension Sass_EmbeddedProtocol_InboundMessage.Syntax {
    init(_ syntax: Syntax) {
        switch syntax {
        case .css: self = .css
        case .indented, .sass: self = .indented
        case .scss: self = .scss
        }
    }
}

extension Sass_EmbeddedProtocol_InboundMessage.CompileRequest.OutputStyle {
    init(_ style: CssStyle) {
        switch style {
        case .compact: self = .compact
        case .compressed: self = .compressed
        case .expanded: self = .expanded
        case .nested: self = .nested
        }
    }
}

extension Sass_EmbeddedProtocol_InboundMessage.CompileRequest.Importer {
    init(_ importer: ImportResolver, id: UInt32) {
        self.init()
        switch importer {
        case .loadPath(let url):
            path = url.path
        case .importer(_):
            importerID = id
        }
    }
}

extension Array where Element == Sass_EmbeddedProtocol_InboundMessage.CompileRequest.Importer {
    init(_ importers: [ImportResolver], startingID: UInt32) {
        self = importers.enumerated().map {
            .init($0.1, id: UInt32($0.0) + startingID)
        }
    }
}

// MARK: Inbound message polymorphism

// Not sure this needs to be a protocol, TODO-NIO
protocol Loggable {
    var logMessage: String { get }
}

extension Sass_EmbeddedProtocol_OutboundMessage : Loggable {
    var logMessage: String {
        message?.logMessage ?? "unknown-1"
    }

    var compilationID: UInt32? {
        message?.compilationID
    }
}

extension Sass_EmbeddedProtocol_OutboundMessage.OneOf_Message : Loggable {
    var logMessage: String {
        switch self {
        case .canonicalizeRequest(let m): return m.logMessage
        case .compileResponse(let m): return m.logMessage
        case .error(let m): return m.logMessage
//      case .fileImportRequest(let m): return m.logMessage
        case .functionCallRequest(let m): return m.logMessage
        case .importRequest(let m): return m.logMessage
        case .logEvent(let m): return m.logMessage
        default: return "unknown-2"
        }
    }

    var compilationID: UInt32? {
        switch self {
        case .canonicalizeRequest(let m): return m.compilationID
        case .compileResponse(let m): return UInt32(m.id) // XXX oops bad protobuf
        case .error(_): return nil
//      case .fileImportRequest(let m): return m.compilationID
        case .functionCallRequest(let m): return m.compilationID
        case .importRequest(let m): return m.compilationID
        case .logEvent(let m): return m.compilationID
        default: return nil
        }
    }
}

extension Sass_EmbeddedProtocol_ProtocolError : Loggable {
    var logMessage: String {
        "protocol-error id=\(id)"
    }
}
extension Sass_EmbeddedProtocol_OutboundMessage.CompileResponse : Loggable {
    var logMessage: String {
        "compile-response compid=\(id)"
    }
}

extension Sass_EmbeddedProtocol_OutboundMessage.LogEvent : Loggable {
    var logMessage: String {
        "log-event compid=\(compilationID)"
    }
}

extension Sass_EmbeddedProtocol_OutboundMessage.CanonicalizeRequest : Loggable {
    var logMessage: String {
        "canon-req compid=\(compilationID) reqid=\(id) impid=\(importerID)"
    }
}

extension Sass_EmbeddedProtocol_OutboundMessage.ImportRequest : Loggable {
    var logMessage: String {
        "import-req compid=\(compilationID) reqid=\(id) impid=\(importerID)"
    }
}

//extension Sass_EmbeddedProtocol_OutboundMessage.FileImportRequest : Loggable {
//    var logMessage: String {
//        "file-import-req compid=\(compilationID) reqid=\(id) impid=\(importerID)"
//    }
//}

extension Sass_EmbeddedProtocol_OutboundMessage.FunctionCallRequest : Loggable {
    var logMessage: String {
        "fncall-req compid=\(compilationID) reqid=\(id) fnid=\(identifier?.logMessage ?? "[nil]")"
    }
}

extension Sass_EmbeddedProtocol_OutboundMessage.FunctionCallRequest.OneOf_Identifier : Loggable {
    var logMessage: String {
        switch self {
        case .functionID(let id): return String(id)
        case .name(let name): return name
        }
    }
}

// MARK: SassValue conversion

// Protobuf -> SassValue

extension SassList.Separator {
    init(_ separator: Sass_EmbeddedProtocol_Value.List.Separator) throws {
        switch separator {
        case .comma: self = .comma
        case .slash: self = .slash
        case .space: self = .space
        case .undecided: self = .undecided
        case .UNRECOGNIZED(let u):
            throw ProtocolError("Unrecognized list separator: \(u)")
        }
    }
}

extension Sass_EmbeddedProtocol_Value {
    func asSassValue() throws -> SassValue {
        switch value {
        case .string(let m):
            return SassString(m.text, isQuoted: m.quoted)
        case .list(let l):
            return try SassList(l.contents.map { try $0.asSassValue() },
                                separator: .init(l.separator),
                                hasBrackets: l.hasBrackets_p)
        case .singleton(let s):
            switch s {
            case .false: return SassConstants.false
            case .true: return SassConstants.true
            case .null: return SassConstants.null
            case .UNRECOGNIZED(let i):
                throw ProtocolError("Unknown singleton type \(i)")
            }
        case nil:
            throw ProtocolError("Missing SassValue type.")
        default:
            // TODO: delete when switch is exhaustive
            throw ProtocolError("Unsupported SassValue type: \(String(describing: value))")
        }
    }
}

// SassValue -> Protobuf

extension Sass_EmbeddedProtocol_Value.List.Separator {
    init(_ separator: SassList.Separator) {
        switch separator {
        case .comma: self = .comma
        case .slash: self = .slash
        case .space: self = .space
        case .undecided: self = .undecided
        }
    }
}

extension Sass_EmbeddedProtocol_Value: SassValueVisitor {
    func visit(string: SassString) throws -> OneOf_Value {
        .string(.with {
            $0.text = string.text
            $0.quoted = string.isQuoted
        })
    }

    func visit(list: SassList) throws -> OneOf_Value {
        .list(.with {
            $0.separator = .init(list.separator)
            $0.hasBrackets_p = list.hasBrackets
            $0.contents = list.map { .init($0) }
        })
    }

    func visit(bool: SassBool) throws -> OneOf_Value {
        .singleton(bool.value ? .true : .false)
    }

    func visit(null: SassNull) throws -> OneOf_Value {
        .singleton(.null)
    }

    init(_ val: SassValue) {
        self.value = try! val.accept(visitor: self)
    }
}
