//
//  Exec.swift
//  TMLMisc -> SourceKittenFramework -> BebopLib -> EmbeddedSass
//
//  Copyright © 2019 SourceKitten. All rights reserved.
//  Copyright 2020 Bebop Authors
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/main/LICENSE)
//

import Foundation
import NIO

/// Create a pair of connected sockets in PF_LOCAL.
private struct SocketPipe {
    let reader: FileHandle
    let writer: FileHandle

    init() {
        var fds: [Int32] = [0, 0]
        #if os(Linux)
        let sockStream = Int32(SOCK_STREAM.rawValue)
        #else
        let sockStream = SOCK_STREAM
        #endif // such anger
        let rc = socketpair(PF_LOCAL, sockStream, 0, &fds)
        precondition(rc == 0, "socketpair(2) failed errno=\(errno)")
        reader = FileHandle(fileDescriptor: fds[0])
        writer = FileHandle(fileDescriptor: fds[1])
    }
}

/// Namespace for utilities to execute a child process.
enum Exec {
    /// How to handle stderr output from the child process.
    enum Stderr {
        /// Treat stderr same as parent process.
        case inherit
        /// Send stderr to /dev/null.
        case discard
        /// Merge stderr with stdout.
        case merge
    }

    /// The result of running the child process.
    struct Results {
        /// The command that was run
        let command: String
        /// Its arguments
        let arguments: [String]
        /// The process's exit status.
        let terminationStatus: Int32
        /// The data from stdout and optionally stderr.
        let data: Data
        /// The `data` reinterpreted as a string with whitespace trimmed; `nil` for the empty string.
        var string: String? {
            let encoded = String(data: data, encoding: .utf8) ?? ""
            let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        /// The `data` reinterpreted as a string but intercepted to `nil` if the command actually failed
        var successString: String? {
            guard terminationStatus == 0 else {
                return nil
            }
            return string
        }
        /// Some text explaining a failure
        var failureReport: String {
            var report = """
            Command failed: \(command)
            Arguments: \(arguments)
            Exit status: \(terminationStatus)
            """
            if let output = string {
                report += ", output:\n\(output)"
            }
            return report
        }
    }

    /**
    Run a command with arguments and return its output and exit status.

    - parameter command: Absolute path of the command to run.
    - parameter arguments: Arguments to pass to the command.
    - parameter currentDirectory: Current directory for the command.  By default
                                  the parent process's current directory.
    - parameter stderr: What to do with stderr output from the command.  By default
                        whatever the parent process does.
    */
    static func run(_ command: String,
                    _ arguments: String...,
                    currentDirectory: String = FileManager.default.currentDirectoryPath,
                    stderr: Stderr = .inherit) -> Results {
        return run(command, arguments, currentDirectory: currentDirectory, stderr: stderr)
    }

    /**
     Run a command with arguments and return its output and exit status.

     - parameter command: Absolute path of the command to run.
     - parameter arguments: Arguments to pass to the command.
     - parameter currentDirectory: Current directory for the command.  By default
                                   the parent process's current directory.
     - parameter stderr: What to do with stderr output from the command.  By default
                         whatever the parent process does.
     */
     static func run(_ command: String,
                     _ arguments: [String] = [],
                     currentDirectory: String = FileManager.default.currentDirectoryPath,
                     stderr: Stderr = .inherit) -> Results {
        let process = Process()
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        switch stderr {
        case .discard:
            // FileHandle.nullDevice does not work here, as it consists of an invalid file descriptor,
            // causing process.launch() to abort with an EBADF.
            process.standardError = FileHandle(forWritingAtPath: "/dev/null")!
        case .merge:
            process.standardError = pipe
        case .inherit:
            break
        }

        do {
          process.executableURL = URL(fileURLWithPath: command)
          process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
          try process.run()
        } catch {
            return Results(command: command, arguments: arguments, terminationStatus: -1, data: Data())
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Results(command: process.executableURL?.path ?? "",
                       arguments: process.arguments ?? [],
                       terminationStatus: process.terminationStatus,
                       data: data)
    }

    /// Start an asynchrous child process with NIO connections.
    ///
    /// Doesn't work on an event loop -- a weird underlying NIO design point we lean into: this
    /// blocks a little as the process starts.
    ///
    /// - parameter command: Absolute path of the command to run
    /// - parameter arguments: Arguments to pass to the command
    /// - parameter currentDirectory: Current directory for the command.  By default
    ///                               the parent process's current directory.
    ///
    /// - throws: Whatever `Process.run()` does if the command is bad.
    /// - returns: `Exec.Child` for the child process.
    ///
    /// Stderr of the child process is discarded because I don't want it rn.
    static func spawn(_ command: URL,
                      _ arguments: [String] = [],
                      currentDirectory: String = FileManager.default.currentDirectoryPath,
                      group: EventLoopGroup) throws -> Child {
        let process = Process()
        process.arguments = arguments

        // Some pain in getting this working with NIO.
        // Lesson 1: Don't let NIO anywhere near a pipe(2) fd, it doesn't
        // understand how they work.
        // Lesson 2: Don't let NIO anywhere near the 'child' ends of the
        // non-pipe FDs, even when closed it messes up on Linux.
        // Lesson 3: Don't think too hard about `withInputOutputDescriptor()`
        // dup-ing the FD, just don't use it for anything.

        let stdoutPipe = SocketPipe()
        let stdinPipe = SocketPipe()

        process.standardOutput = stdoutPipe.writer
        process.standardInput = stdinPipe.reader
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")!

        process.executableURL = command
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        try process.run()

        let stdoutChannel = try NIOPipeBootstrap(group: group)
            .withInputOutputDescriptor(stdoutPipe.reader.fileDescriptor)
            .wait()

        let stdinChannel = try NIOPipeBootstrap(group: group)
            .withInputOutputDescriptor(stdinPipe.writer.fileDescriptor)
            .wait()

        // Close our copy of the FDs that the child is using.
        try stdoutPipe.writer.close()
        try stdinPipe.reader.close()

        print("FDs all set up")
        check(stdoutPipe.reader.fileDescriptor, "reader-init")
        check(stdinPipe.writer.fileDescriptor, "writer-init")

        let c = Child(process: process, stdin: stdinChannel, stdout: stdoutChannel)
        c.fds = [stdoutPipe.reader.fileDescriptor, stdinPipe.writer.fileDescriptor]
        return c
    }

    /// A running child process with NIO connections.
    ///
    /// When the last reference to this object is released it blocks for process termination;
    /// no action taken here to ensure this termination though.
    final class Child {
        /// The `Process` object for the child
        let process: Process
        /// The child's `stdin`.  Write to it.
        let standardInput: Channel
        /// The child's `stdout`.  Read from it.
        let standardOutput: Channel

        var fds: [Int32] = []

        func reportFDs(_ str: String) {
            check(fds[0], "reader-check \(str)")
            check(fds[1], "writer-check \(str)")
        }

        init(process: Process, stdin: Channel, stdout: Channel) {
            self.process = process
            self.standardInput = stdin
            self.standardOutput = stdout
        }

        deinit {
            process.waitUntilExit()
        }
    }
}


func check(_ fd: Int32, _ str: String) {
    var statbuf = stat()
    let rc = fstat(fd, &statbuf)
    print("stat \(fd) \(str) = \(rc)")
}
