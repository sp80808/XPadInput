import Foundation
import AVFoundation
import XCTest
@testable import XPadAudio

final class ErrorReportingTests: XCTestCase {
    func testRecorderWriteErrorIsNilWhileCaptureIsHealthy() throws {
        let recorder = LoopbackAudioRecorder()
        XCTAssertNil(recorder.lastWriteErrorDescription, "New recorder reports no write error")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_error_reporting_capture.wav")
        try? FileManager.default.removeItem(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try recorder.startRecording(outputURL: tempURL, sampleRate: 44100.0, channels: 2)
        XCTAssertNil(recorder.lastWriteErrorDescription, "Starting a capture clears any prior write error")

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128))
        buffer.frameLength = 128
        recorder.recordBuffer(buffer)

        XCTAssertNil(recorder.lastWriteErrorDescription, "Successful writes leave no error")
        XCTAssertTrue(recorder.isRecording, "Capture stays active after a successful write")
        XCTAssertEqual(recorder.recordedFrames, 128)

        recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.lastWriteErrorDescription, "Clean stop leaves no error")
    }

    func testRecorderWriteErrorIsReadableConcurrentlyWithWrites() throws {
        let recorder = LoopbackAudioRecorder()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_error_reporting_concurrent.wav")
        try? FileManager.default.removeItem(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try recorder.startRecording(outputURL: tempURL, sampleRate: 44100.0, channels: 2)

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
        buffer.frameLength = 64

        let writer = Thread {
            for _ in 0..<200 {
                recorder.recordBuffer(buffer)
            }
        }
        writer.start()

        // Reader mirrors the UI polling the failure state during capture.
        for _ in 0..<200 {
            XCTAssertNil(recorder.lastWriteErrorDescription)
        }

        while !writer.isFinished {
            Thread.sleep(forTimeInterval: 0.001)
        }
        recorder.stopRecording()
    }

    func testStartErrorDescriptionMatchesRunningState() {
        let engine = AudioEngine()
        engine.start()

        if engine.isRunning {
            XCTAssertNil(engine.startErrorDescription, "Successful start clears the failure description")
        } else {
            XCTAssertNotNil(engine.startErrorDescription, "Failed start reports why the engine is not running")
        }

        // Note and drum events must never crash regardless of start outcome;
        // when the engine cannot run they are dropped instead of allocating voices.
        engine.noteOn(note: 60, velocity: 100)
        engine.triggerDrum(.kick, velocity: 100)
        engine.noteOff(note: 60)

        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }
}
