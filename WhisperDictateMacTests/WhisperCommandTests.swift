import XCTest
@testable import WhisperDictateMac

final class WhisperCommandTests: XCTestCase {
    func testCommandIncludesMLXModelAudioTextOutputAndLanguage() throws {
        let executableURL = FileManager.default.temporaryDirectory.appendingPathComponent("fake-mlx-whisper")
        FileManager.default.createFile(atPath: executableURL.path, contents: Data("#!/bin/sh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("sample.wav")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let command = try WhisperTranscriber().makeCommand(
            audioURL: audioURL,
            configuration: WhisperConfiguration(
                executablePath: executableURL.path,
                model: "mlx-community/whisper-large-v3-turbo",
                language: "pt"
            )
        )

        XCTAssertEqual(command.executableURL.path, executableURL.path)
        XCTAssertTrue(command.arguments.contains("mlx-community/whisper-large-v3-turbo"))
        XCTAssertTrue(command.arguments.contains(audioURL.path))
        XCTAssertTrue(command.arguments.contains("--output-format"))
        XCTAssertTrue(command.arguments.contains("txt"))
        XCTAssertTrue(command.arguments.contains("--verbose"))
        XCTAssertTrue(command.arguments.contains("False"))
        XCTAssertTrue(command.arguments.contains("--language"))
        XCTAssertTrue(command.arguments.contains("pt"))
        XCTAssertEqual(command.outputTextURL.lastPathComponent, "transcript.txt")
    }
}
