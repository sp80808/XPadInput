import Foundation
import AVFoundation
import XPadAudio

public enum VirtualAudioDriverTestSuite {
    public static func runTests(
        assertEqual: (Any, Any, String) -> Void,
        assertTrue: (Bool, String) -> Void,
        assertFalse: (Bool, String) -> Void,
        assertNotNil: (Any?, String) -> Void
    ) {
        // 1. AudioRingBuffer Tests
        let ringBuffer = AudioRingBuffer(channels: 2, capacityFrames: 1024)
        assertEqual(ringBuffer.channels, 2, "Ring buffer channels")
        assertEqual(ringBuffer.capacityFrames, 1024, "Ring buffer capacity")
        assertEqual(ringBuffer.availableReadFrames, 0, "Initial available read frames")

        // Contiguous write and read
        let testInputL: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let testInputR: [Float] = [0.6, 0.7, 0.8, 0.9, 1.0]

        testInputL.withUnsafeBufferPointer { ptrL in
            testInputR.withUnsafeBufferPointer { ptrR in
                let written = ringBuffer.writeStereo(left: ptrL.baseAddress!, right: ptrR.baseAddress!, frameCount: 5)
                assertEqual(written, 5, "Written stereo frames")
            }
        }

        assertEqual(ringBuffer.availableReadFrames, 5, "Available read frames after write")

        var readOutput = [Float](repeating: 0.0, count: 10) // 5 frames * 2 channels
        readOutput.withUnsafeMutableBufferPointer { ptr in
            let readFrames = ringBuffer.readInterleaved(into: ptr.baseAddress!, frameCount: 5)
            assertEqual(readFrames, 5, "Read interleaved frames count")
        }

        assertEqual(readOutput[0], 0.1, "Sample 0 L")
        assertEqual(readOutput[1], 0.6, "Sample 0 R")
        assertEqual(readOutput[8], 0.5, "Sample 4 L")
        assertEqual(readOutput[9], 1.0, "Sample 4 R")
        assertEqual(ringBuffer.availableReadFrames, 0, "Buffer empty after reading all")

        // Wrap-around write test
        let largeWriteL = [Float](repeating: 0.25, count: 800)
        let largeWriteR = [Float](repeating: 0.25, count: 800)
        largeWriteL.withUnsafeBufferPointer { ptrL in
            largeWriteR.withUnsafeBufferPointer { ptrR in
                _ = ringBuffer.writeStereo(left: ptrL.baseAddress!, right: ptrR.baseAddress!, frameCount: 800)
            }
        }
        var largeRead = [Float](repeating: 0.0, count: 1600)
        largeRead.withUnsafeMutableBufferPointer { ptr in
            _ = ringBuffer.readInterleaved(into: ptr.baseAddress!, frameCount: 800)
        }
        assertEqual(ringBuffer.availableReadFrames, 0, "Read all large chunk")

        // Now head is near end of buffer, perform wrap-around write
        let wrapWriteL = [Float](repeating: 0.75, count: 500)
        let wrapWriteR = [Float](repeating: 0.75, count: 500)
        wrapWriteL.withUnsafeBufferPointer { ptrL in
            wrapWriteR.withUnsafeBufferPointer { ptrR in
                let written = ringBuffer.writeStereo(left: ptrL.baseAddress!, right: ptrR.baseAddress!, frameCount: 500)
                assertEqual(written, 500, "Wrap-around write")
            }
        }
        assertEqual(ringBuffer.availableReadFrames, 500, "Available read frames after wrap-around")

        var wrapRead = [Float](repeating: 0.0, count: 1000)
        wrapRead.withUnsafeMutableBufferPointer { ptr in
            let read = ringBuffer.readInterleaved(into: ptr.baseAddress!, frameCount: 500)
            assertEqual(read, 500, "Wrap-around read")
        }
        assertEqual(wrapRead[0], 0.75, "Wrap sample L")
        assertEqual(wrapRead[1], 0.75, "Wrap sample R")

        ringBuffer.reset()
        assertEqual(ringBuffer.availableReadFrames, 0, "Available read frames after reset")

        // 2. AudioLevelMeter Tests
        let meter = AudioLevelMeter()
        let loudAudioL: [Float] = [0.8, -0.8, 0.8, -0.8]
        let loudAudioR: [Float] = [0.4, -0.4, 0.4, -0.4]
        loudAudioL.withUnsafeBufferPointer { pL in
            loudAudioR.withUnsafeBufferPointer { pR in
                meter.processFrames(left: pL.baseAddress!, right: pR.baseAddress!, frameCount: 4)
            }
        }
        assertTrue(meter.peakLeft >= 0.8, "Peak left detected")
        assertTrue(meter.peakRight >= 0.4, "Peak right detected")
        assertTrue(meter.peakLeftDB > -3.0, "Peak dB level accurate")
        assertTrue(meter.rmsLeft > 0.5, "RMS level accurate")

        // 3. VirtualAudioDriver Tests
        let driver = VirtualAudioDriver(ringBufferCapacity: 2048)
        assertFalse(driver.isEnabled, "Driver disabled by default")
        driver.setEnabled(true)
        assertTrue(driver.isEnabled, "Driver enabled")

        driver.setSampleRate(.rate48k0)
        assertEqual(driver.sampleRate, VirtualAudioSampleRate.rate48k0, "Sample rate 48kHz")

        driver.setBufferSize(.lowLatency64)
        assertEqual(driver.bufferSize, VirtualAudioBufferSize.lowLatency64, "Buffer latency 64 frames")

        // Ingest audio test
        let testFrames: [Float] = [0.5, 0.5, 0.5, 0.5]
        testFrames.withUnsafeBufferPointer { p in
            driver.ingestAudio(left: p.baseAddress!, right: nil, frameCount: 4)
        }
        assertTrue(driver.driverState.totalFramesStreamed >= 4, "Total frames streamed incremented")

        var pulledData = [Float](repeating: 0.0, count: 8)
        pulledData.withUnsafeMutableBufferPointer { p in
            let pulled = driver.pullInterleaved(into: p.baseAddress!, frameCount: 4)
            assertEqual(pulled, 4, "Pulled interleaved frames count")
        }
        assertEqual(pulledData[0], 0.5, "Pulled frame L")
        assertEqual(pulledData[1], 0.5, "Pulled frame R (duplicated mono)")

        driver.setEnabled(false)
        assertFalse(driver.isEnabled, "Driver disabled")

        // 4. LoopbackAudioRecorder Tests
        let recorder = LoopbackAudioRecorder()
        assertFalse(recorder.isRecording, "Recorder idle initially")

        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_loopback_capture.wav")
            try? FileManager.default.removeItem(at: tempURL)

            let fileURL = try recorder.startRecording(outputURL: tempURL, sampleRate: 44100.0, channels: 2)
            assertTrue(recorder.isRecording, "Recorder active")
            assertEqual(fileURL, tempURL, "Output URL matches")

            // Record mock buffer
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
            if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128) {
                pcmBuffer.frameLength = 128
                recorder.recordBuffer(pcmBuffer)
                assertEqual(recorder.recordedFrames, 128, "Recorded frame count")
            }

            let stoppedURL = recorder.stopRecording()
            assertFalse(recorder.isRecording, "Recorder stopped")
            assertEqual(stoppedURL, tempURL, "Stopped URL matches")
            assertTrue(FileManager.default.fileExists(atPath: tempURL.path), "WAV file exists on disk")

            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            assertTrue(false, "LoopbackAudioRecorder test failed: \(error)")
        }
    }
}
