//
//  SassTypes.swift
//  swift-sass
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/master/LICENSE)
//

// Sass interface types, common between any implementation
// Doc comments mostly lifted from sass docs.

/// Namespace
public enum Sass {
    /// Possible ways to format the CSS produced by a Sass compiler.
    public enum OutputStyle {
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

    /// Language used for some input to a Sass compiler.
    public enum InputSyntax {
        /// The CSS-superset `.scss` syntax.
        case scss

        /// The indented `.sass` syntax.
        case indented

        /// Plain CSS syntax that doesn't support any special Sass features.
        case css
    }

    /// Results of a successful compilation.
    public struct Results {
        /// The  CSS output from the compiler.
        public let css: String
        /// The JSON sourcemap, provided only if requested at compile time.
        public let sourceMap: String?
    }

    /// A section of a source file.
    public struct SourceSpan {
        /// The text covered by the source span.
        public let text: String

        /// The URL of the file to which this span refers, or `nil` if it refers to
        /// an inline compilation that doesn't specify a URL.
        public let url: String?

        /// A single point in s source file.
        public struct Location {
            /// The 0-based byte offset of this location within the source file.
            public let offset: Int
            /// The 0-based line number of this location within the source file.
            public let line: Int
            /// The 0-based column number of this location within its line.
            public let column: Int
        }

        /// The location of the first character in this span.
        public let start: Location

        /// The location of the first character after this span, or `nil` to mean
        /// this span is zero-length and points just before `start`.
        public let end: Location?

        /// Additional source text surrounding this span.
        ///
        /// This usually contains the full lines the span begins and ends on if the
        /// span itself doesn't cover the full lines.
        public let context: String?
    }

    /// Kinds of messages generated during compilation that do not prevent a successful result.
    public enum WarningType {
        /// A warning for something other than a deprecated Sass feature. Often
        /// emitted due to a stylesheet using the `@warn` rule.
        case warning

        /// A warning indicating that the stylesheet is using a deprecated Sass
        /// feature. The accompanying text does include text like "deprecation warning".
        case deprecation
    }

    /// A message generated by the compiler during compilation that does not prevent a
    /// successful result.  Appropriate for display to end users that own the stylesheets.
    public struct WarningMessage {
        /// Type of the message.
        public let type: WarningType
        /// Text of the message, english.
        public let message: String
        /// Optionally a description of the source that triggered the log.
        public let span: SourceSpan?
    }

    /// A routine to receive log events during compilation.
    public typealias WarningHandler = (WarningMessage) -> Void

    /// A log message generated by the system.  May help with debug.
    /// Not for end users.
    public struct DebugMessage {
        /// Text of the message, english.
        public let message: String
        /// Optionally a description of the source that triggered the log.
        public let span: SourceSpan?
        /// Stack trace
        public let stackTrace: String?
    }

    /// A routine to receive log events during compilation.
    public typealias DebugHandler = (DebugMessage) -> Void
}
