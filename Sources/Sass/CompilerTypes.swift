//
//  CompilerTypes.swift
//  Sass
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/main/LICENSE
//
//  Much text here taken verbatim or only slightly editted from the embedded Sass
//  protocol specification.
//  Copyright (c) 2019, Google LLC
//  Licensed under MIT (https://github.com/sass/embedded-protocol/blob/master/LICENSE)
//

// Sass compiler interface types, shared between embedded Sass and libsass.

import Foundation

/// How the Sass compiler should format the CSS it produces.
public enum CssStyle {
    /// Each selector and declaration is written on its own line.
    case expanded

    /// The entire stylesheet is written on a single line, with as few
    /// characters as possible.
    case compressed

    /// CSS rules and declarations are indented to match the nesting of the
    /// Sass source.
    case nested

    /// Each CSS rule is written on its own single line, along with all its
    /// declarations.
    case compact
}

/// The [syntax used for a stylesheet](https://sass-lang.com/documentation/syntax).
public enum Syntax {
    /// The CSS-superset `.scss` syntax.
    case scss

    /// The indented `.sass` syntax.
    case indented, sass

    /// Plain CSS syntax that doesn't support any special Sass features.
    case css
}

/// The output from a successful compilation.
public struct CompilerResults {
    /// The  CSS produced by the Sass compiler.
    public let css: String

    /// The JSON sourcemap, provided only if requested at compile time.
    public let sourceMap: String?

    /// Any compiler warnings and debug statements.
    public let messages: [CompilerMessage]

    /// :nodoc:
    public init(css: String, sourceMap: String?, messages: [CompilerMessage]) {
        self.css = css
        self.sourceMap = sourceMap
        self.messages = messages
    }
}

/// Thrown as an error after a failed compilation.
public struct CompilerError: Swift.Error {
    /// A message describing the reason for the failure.
    public let message: String

    /// Optionally, the section of stylesheet that triggered the failure.
    public let span: Span?

    /// The stack trace through the compiler input stylesheets that led to the failure.
    public let stackTrace: String?

    /// Any compiler diagnostics found before the error.
    public let messages: [CompilerMessage]

    /// :nodoc:
    public init(message: String, span: Span?, stackTrace: String?, messages: [CompilerMessage]) {
        self.message = message
        self.span = span
        self.stackTrace = stackTrace
        self.messages = messages
    }
}

/// A section of a stylesheet.
public struct Span: CustomStringConvertible {
    // MARK: Types

    /// A single point in a stylesheet.
    public struct Location: CustomStringConvertible {
        /// The 0-based byte offset of this location within the stylesheet.
        public let offset: Int

        /// The 0-based line number of this location within the stylesheet.
        public let line: Int

        /// The 0-based column number of this location within its line.
        public let column: Int

        /// A short description of the location.  Uses 1-based counting!
        public var description: String {
            "\(line + 1):\(column + 1)"
        }

        /// :nodoc:
        public init(offset: Int, line: Int, column: Int) {
            self.offset = offset
            self.line = line
            self.column = column
        }
    }

    // MARK: Properties

    /// The text covered by the span, or `nil` if there is no
    /// associated text.
    public let text: String?

    /// The URL of the stylesheet to which the span refers, or `nil` if it refers to
    /// an inline compilation that doesn't specify a URL.
    public let url: URL?


    /// The location of the first character in the span.
    public let start: Location

    /// The location of the first character after this span, or `nil` to mean
    /// the span is zero-length and points just before `start`.
    public let end: Location?

    /// Additional source text surrounding the span.
    ///
    /// This usually contains the full lines the span begins and ends on if the
    /// span itself doesn't cover the full lines.
    public let context: String?

    /// A short human-readable description of the span. :nodoc:
    public var description: String {
        var desc = url?.lastPathComponent ?? "[input]"
        desc.append(" \(start)")
        if let end = end {
            desc.append("-\(end)")
        }
        return desc
    }

    /// :nodoc:
    public init(text: String?, url: URL?, start: Location, end: Location?, context: String?) {
        self.text = text
        self.url = url
        self.start = start
        self.end = end
        self.context = context
    }
}

/// A diagnostic message generated by the Sass compiler that does not prevent the compilation
/// from succeeding.
///
/// Appropriate for display to end users who own the stylesheets.
public struct CompilerMessage {
    // MARK: Types

    /// Kinds of diagnostic message.
    public enum Kind {
        /// A warning for something other than a deprecated Sass feature. Often
        /// emitted due to a stylesheet using the [`@warn` rule](https://sass-lang.com/documentation/at-rules/warn).
        case warning

        /// A warning indicating that the stylesheet is using a deprecated Sass
        /// feature. The accompanying text does not include text like "deprecation warning".
        case deprecation

        /// Text from a [`@debug` rule](https://sass-lang.com/documentation/at-rules/debug).
        case debug
    }

    // MARK: Properties

    /// The kind of the message.
    public let kind: Kind

    /// The text of the message.
    public let message: String

    /// Optionally, the section of stylesheet that triggered the message.
    public let span: Span?

    /// The stack trace through the compiler input stylesheets that led to the message.
    public let stackTrace: String?

    /// :nodoc:
    public init(kind: Kind, message: String, span: Span?, stackTrace: String?) {
        self.kind = kind
        self.message = message
        self.span = span
        self.stackTrace = stackTrace
    }
}

// MARK: Compiler interface

/// The top-level interfaces to a Sass compiler implementation. :nodoc:
public protocol CompilerProtocol {
    // this protocol mostly exists to inherit doc comments but also
    // to try and ensure matching function from implementations...
    /// Compile to CSS from a stylesheet file.
    ///
    /// - parameters:
    ///   - fileURL: The `file:` URL to compile.  The file extension determines the
    ///     expected syntax of the contents, so it must be css/scss/sass.
    ///   - outputStyle: How to format the produced CSS.  Default `.expanded`.
    ///   - createSourceMap: Create a JSON source map for the CSS.  Default `false`.
    ///   - importers: Rules for resolving `@import` etc. for this compilation, used in order after
    ///     `sourceFileURL`'s directory and any set globally..  Default none.
    ///   - functions: Functions for this compilation, overriding any with the same name previously
    ///     set globally. Default none.
    /// - throws: `CompilerError` if there is a critical error with the input, for example a syntax error.
    ///           Some other kind of error if something goes wrong  with the compiler infrastructure itself.
    /// - returns: `CompilerResults` with CSS and optional source map.
    func compile(fileURL: URL,
                 outputStyle: CssStyle,
                 createSourceMap: Bool,
                 importers: [ImportResolver],
                 functions: SassFunctionMap) throws -> CompilerResults

    /// Compile to CSS from an inline stylesheet.
    ///
    /// - parameters:
    ///   - text: The stylesheet text to compile.
    ///   - syntax: The syntax of `text`, default `.scss`.
    ///   - url: The absolute URL to associate with `text`.  Default `nil` meaning unknown.
    ///   - outputStyle: How to format the produced CSS.  Default `.expanded`.
    ///   - createSourceMap: Create a JSON source map for the CSS.  Default `false`.
    ///   - importers: Rules for resolving `@import` etc. for this compilation, used in order after
    ///     any set globally.  Default none.
    ///   - functions: Functions for this compilation, overriding any with the same name previously
    ///     set globally.  Default none.
    /// - throws: `CompilerError` if there is a critical error with the input, for example a syntax error.
    ///           Some other kind of error if something goes wrong  with the compiler infrastructure itself.
    /// - returns: `CompilerResults` with CSS and optional source map.
    ///
    /// Ought to have a special importer to go with `url` but compiler doesn't implement it so ....
    func compile(text: String,
                 syntax: Syntax,
                 url: URL?,
                 outputStyle: CssStyle,
                 createSourceMap: Bool,
                 importers: [ImportResolver],
                 functions: SassFunctionMap) throws -> CompilerResults
}

// MARK: Message pretty-printers

/// Gadget to share implementation between the subtly different error/warning/debug log types.
protocol LogFormatter {
    var message: String { get }
    var messageType: String { get }
    var span: Span? { get }
    var stackTrace: String? { get }
    var description: String { get }
}

extension LogFormatter {
    var baseDescription: String {
        var desc = span.flatMap { "\($0): " } ?? ""
        desc += "\(messageType): "
        desc += message
        if let trace = stackTrace?.trimmingCharacters(in: .newlines),
           !trace.isEmpty {
            let paddedTrace = trace.split(separator: "\n")
                .map { "    " + $0 }
                .joined(separator: "\n")
            desc += "\n\(paddedTrace)"
        }
        return desc
    }

    public var description: String { baseDescription }
}

extension CompilerError: CustomStringConvertible {}
extension CompilerError: LogFormatter {
    var messageType: String { "error" }

    /// A  human-readable description of the message. :nodoc:
    public var description: String {
        messages.map { "\($0.description)\n" }.joined() + baseDescription
    }
}

extension CompilerMessage.Kind: CustomStringConvertible {
    /// A human-readable description of the message kind. :nodoc:
    public var description: String {
        switch self {
        case .deprecation: return "deprecation warning"
        case .warning: return "warning"
        case .debug: return "debug"
        }
    }
}

extension CompilerMessage: CustomStringConvertible {}
extension CompilerMessage: LogFormatter {
    var messageType: String { kind.description }
}
