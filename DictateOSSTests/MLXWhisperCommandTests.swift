import XCTest
@testable import DictateOSS

final class MLXWhisperCommandTests: XCTestCase {
    func testCommandIncludesModelAudioTextOutputAndLanguage() throws {
        let executableURL = try makeExecutable(named: "fake-mlx-whisper")
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("sample.m4a")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let command = try MLXWhisperTranscriber().makeCommand(
            audioURL: audioURL,
            configuration: MLXWhisperConfiguration(
                executablePath: executableURL.path,
                model: "mlx-community/whisper-large-v3-turbo",
                language: "pt"
            )
        )
        defer { try? FileManager.default.removeItem(at: command.outputDirectoryURL) }

        XCTAssertEqual(command.executableURL.path, executableURL.path)
        XCTAssertTrue(command.arguments.contains(audioURL.path))
        XCTAssertTrue(command.arguments.contains("mlx-community/whisper-large-v3-turbo"))
        XCTAssertTrue(command.arguments.contains("--output-format"))
        XCTAssertTrue(command.arguments.contains("txt"))
        XCTAssertTrue(command.arguments.contains("--verbose"))
        XCTAssertTrue(command.arguments.contains("False"))
        XCTAssertTrue(command.arguments.contains("--language"))
        XCTAssertTrue(command.arguments.contains("pt"))
        XCTAssertEqual(command.outputTextURL.lastPathComponent, "transcript.txt")
    }

    func testCommandOmitsLanguageWhenAuto() throws {
        let executableURL = try makeExecutable(named: "fake-mlx-whisper-auto")
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let command = try MLXWhisperTranscriber().makeCommand(
            audioURL: URL(fileURLWithPath: "/tmp/sample.m4a"),
            configuration: MLXWhisperConfiguration(
                executablePath: executableURL.path,
                model: "mlx-community/whisper-large-v3-turbo",
                language: "auto"
            )
        )
        defer { try? FileManager.default.removeItem(at: command.outputDirectoryURL) }

        XCTAssertFalse(command.arguments.contains("--language"))
    }

    func testCommandRejectsEmptyModel() throws {
        let executableURL = try makeExecutable(named: "fake-mlx-whisper-empty-model")
        defer { try? FileManager.default.removeItem(at: executableURL) }

        XCTAssertThrowsError(
            try MLXWhisperTranscriber().makeCommand(
                audioURL: URL(fileURLWithPath: "/tmp/sample.m4a"),
                configuration: MLXWhisperConfiguration(
                    executablePath: executableURL.path,
                    model: " ",
                    language: "pt"
                )
            )
        ) { error in
            XCTAssertEqual(error as? MLXWhisperError, .modelMissing)
        }
    }

    func testCommandRejectsMissingExecutable() {
        XCTAssertThrowsError(
            try MLXWhisperTranscriber().makeCommand(
                audioURL: URL(fileURLWithPath: "/tmp/sample.m4a"),
                configuration: MLXWhisperConfiguration(
                    executablePath: "/tmp/does-not-exist/mlx_whisper",
                    model: "mlx-community/whisper-large-v3-turbo",
                    language: "pt"
                )
            )
        )
    }

    func testCommandExpandsTildeInLocalModelPath() throws {
        let executableURL = try makeExecutable(named: "fake-mlx-whisper-local-model")
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let command = try MLXWhisperTranscriber().makeCommand(
            audioURL: URL(fileURLWithPath: "/tmp/sample.m4a"),
            configuration: MLXWhisperConfiguration(
                executablePath: executableURL.path,
                model: "~/models/whisper-local",
                language: "en"
            )
        )
        defer { try? FileManager.default.removeItem(at: command.outputDirectoryURL) }

        guard let modelIndex = command.arguments.firstIndex(of: "--model") else {
            return XCTFail("Expected --model argument")
        }
        XCTAssertEqual(command.arguments[modelIndex + 1], "\(NSHomeDirectory())/models/whisper-local")
    }

    private func makeExecutable(named name: String) throws -> URL {
        let executableURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: executableURL.path, contents: Data("#!/bin/sh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        return executableURL
    }
}
