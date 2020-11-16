//
//  Errors.swift
//  EmbeddedSass
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/master/LICENSE)
//

// Errors thrown by this module

/// There was an error communicating with the embedded sass compiler.
/// The payload is english text describing the nature of the problem.  There is probably nothing that
/// a user can do about this.
public struct ProtocolError: Error {
    public let text: String

    init(_ text: String) {
        self.text = text
    }
}

// Sass.CompilerError ?
public struct CompilerError: Error {
    public let message: String
    public let span: Sass.SourceSpan?
    public let stackTrace: String?
}
