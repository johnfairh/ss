//
//  Compiler.swift
//  DartSass
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/master/LICENSE)
//

import Foundation

/// An instance of the Dart Sass compiler.
///
/// It runs the compiler as a child process and lets you provide importers and Sass Script routines
/// in your Swift code.
///
/// Most simple usage looks like:
/// ```swift
/// do {
///    let compiler = try Compiler()
///    let results = try compiler.compile(sourceFileURL: sassFileURL)
///    print(results.css)
/// } catch {
/// }
/// ```
///
/// Separately to this package you need to supply the `dart-sass-embedded` program or some
/// other thing supporting the Embedded Sass protocol that this class runs under the hood.
///
/// Use `Compiler.warningHandler` to get sight of warnings from the compiler.
///
/// Xxx importers
/// Xxx SassScript
///
/// To debug problems, start with the output from `Compiler.debugHandler`, all the source files
/// being given to the compiler, and the description of any errors thrown.
public final class Compiler {
    private var child: Exec.Child
    private let childRestart: () throws -> Exec.Child

    private enum State {
        /// Nothing happening
        case idle
        /// CompileRequest outstanding, it has initiative
        case active
        /// CompileRequest outstanding, InboundAckedRequest outstanding, user closure active, we have initiative
        case active_callback(String)
        /// Killed them because of error, won't restart
        case idle_broken

        var compileRequestLegal: Bool {
            switch self {
            case .idle, .idle_broken: return true
            case .active, .active_callback(_): return false
            }
        }
    }
    private var state: State

    public init(embeddedDartSass: URL) throws {
        childRestart = { try Exec.spawn(embeddedDartSass) }
        child = try childRestart()
        state = .idle
    }

    deinit {
        child.process.terminate()
    }

    /// An optional callback to receive warning messages from the compiler.
    public var warningHandler: Sass.WarningHandler?

    /// An optional callback to receive debug log messages from us & the compiler.
    public var debugHandler: Sass.DebugHandler?

    private func debug(_ msg: @autoclosure () -> String) {
        debugHandler?(.init(message: "Host: \(msg())", span: nil, stackTrace: nil))
    }

    /// Compile to CSS from a local file.
    ///
    /// - parameters:
    ///   - sourceFileURL: The file:// URL to compile.  The file extension is used to guess the
    ///                    syntax of the contents.
    ///   - outputStyle: How to format the produced CSS.
    ///   - createSourceMap: Create a JSON source map for the CSS.
    /// - throws: `SassError.compilerError()` if there is a critical error with the input, for
    ///           example a syntax error.
    ///           `SassError.protocolError()` if something goes wrong with the compiler
    ///           infrastructure itself.
    /// - returns: CSS and optional source map.
    /// - precondition: no call to `compile(...)` outstanding on this instance.
    ///
    /// XXX describe callbacks
    /// XXX importer rules
    public func compile(sourceFileURL: URL,
                        outputStyle: Sass.OutputStyle = .expanded,
                        createSourceMap: Bool = false) throws -> Sass.Results {
        throw CompilerError("Not implemented")
    }

    /// Compile to CSS from some text.
    ///
    /// - parameters:
    ///   - sourceText: The document to compile.
    ///   - sourceSyntax: The syntax of `sourceText`.
    ///   - outputStyle: How to format the produced CSS.
    ///   - createSourceMap: Create a JSON source map for the CSS.
    /// - throws: `SassError.compilerError()` if there is a critical error with the input, for
    ///           example a syntax error.
    ///           `SassError.protocolError()` if something goes wrong with the compiler
    ///           infrastructure itself.
    /// - returns: CSS and optional source map.
    /// - precondition: no call to `compile(...)` outstanding on this instance.
    ///
    /// XXX describe callbacks
    /// XXX special importer + rules
    public func compile(sourceText: String,
                        sourceSyntax: Sass.InputSyntax = .scss,
                        outputStyle: Sass.OutputStyle = .expanded,
                        createSourceMap: Bool = false) throws -> Sass.Results {
        try compile(input: .string(.with { m in
                        m.source = sourceText
                        // m.syntax = xxx
                    }),
                    outputStyle: outputStyle,
                    createSourceMap: createSourceMap)
    }

    /// Helper to generate the compile request message
    private func compile(input: Sass_EmbeddedProtocol_InboundMessage.CompileRequest.OneOf_Input,
                         outputStyle: Sass.OutputStyle,
                         createSourceMap: Bool) throws -> Sass.Results {
        try compile(message: .with { wrapper in
            wrapper.message = .compileRequest(.with { msg in
                msg.id = 42 // XXX
                msg.input = input
                // msg.style = xxx
                msg.sourceMap = createSourceMap
            })
        })
    }

    /// Top-level compiler protocol runner.  Handles erp, such as there is.
    private func compile(message: Sass_EmbeddedProtocol_InboundMessage) throws -> Sass.Results {
        precondition(state.compileRequestLegal, "Call to `compile(...)` already active")
        if case .idle_broken = state {
            throw ProtocolError("Sass compiler failed to restart after previous errors.")
        }

        let compilationId = message.compileRequest.id

        do {
            state = .active
            debug("Start CompileRequest id=\(compilationId)")
            try child.send(message: message)
            let results = try receiveMessages()
            state = .idle
            debug("End-Success CompileRequest id=\(compilationId)")
            return results
        }
        catch let error as CompilerError {
            state = .idle
            debug("End-CompilerError CompileRequest id=\(compilationId)")
            throw error
        }
        catch {
            // error with some layer of the protocol.
            // the only erp we have to is to try and restart it.
            do {
                debug("End-ProtocolError CompileRequest id=\(compilationId), restarting")
                child.process.terminate()
                child = try childRestart()
                state = .idle
                debug("End-ProtocolError CompileRequest id=\(compilationId), restart OK")
            } catch {
                // the system looks to be broken, sadface
                state = .idle_broken
                debug("End-ProtocolError CompileRequest id=\(compilationId), restart failed (\(error))")
            }
            // Propagate original error
            throw error
        }
    }

    /// Inbound message dispatch, top-level validation
    private func receiveMessages() throws -> Sass.Results {
        while true {
            let response = try child.receive()
            switch response.message {
            case .compileResponse(let rsp):
                debug("  Got CompileResponse")
                return try handleInbound(compileResponse: rsp)

            default:
                throw ProtocolError("Unexpected response: response")
            }
        }
    }

    /// Inbound `CompileResponse` handler
    private func handleInbound(compileResponse: Sass_EmbeddedProtocol_OutboundMessage.CompileResponse) throws -> Sass.Results {
        if compileResponse.id != 42 {
            throw ProtocolError("Bad compilation ID, expected 42 got \(compileResponse.id)")
        }
        switch compileResponse.result {
        case .success(let s):
            return .init(css: s.css, sourceMap: s.sourceMap.isEmpty ? nil : s.sourceMap)
        case .failure(let f):
            // xxx
            throw CompilerError("Sass says no: \(f)")
        case nil:
            // mandatory field is optional
            throw ProtocolError("Malformed CompileResponse, missing `result`: \(compileResponse)")
        }
    }
}
