import Foundation
import AudioToolbox
import AVFoundation
import XPadCore
import XPadTheory
import XPadAudio

public enum AUv3PluginTestSuite {
    public static func runTests(
        assertEqual: (Any, Any, String) -> Void,
        assertTrue: (Bool, String) -> Void,
        assertFalse: (Bool, String) -> Void,
        assertNotNil: (Any?, String) -> Void
    ) {
        // 1. Parameter Tree Test
        let tree = XPadAUParameterTreeBuilder.createParameterTree()
        assertNotNil(tree, "Parameter tree must be instantiated")
        let cutoffParam = tree.parameter(withAddress: XPadAUParameterAddress.filterCutoff.rawValue)
        assertNotNil(cutoffParam, "Filter Cutoff parameter must exist")
        assertEqual(cutoffParam?.minValue ?? 0, 20.0, "Cutoff min value")
        assertEqual(cutoffParam?.maxValue ?? 0, 20000.0, "Cutoff max value")

        let volParam = tree.parameter(withAddress: XPadAUParameterAddress.masterVolume.rawValue)
        assertNotNil(volParam, "Master Volume parameter must exist")
        assertEqual(volParam?.value ?? 0, 0.7, "Default master volume")

        // 2. AUv3 Instrument Instantiation & Rendering Test
        do {
            let desc = XPadPluginRegistrar.instrumentComponentDescription
            let instrument = try XPadAUInstrument(componentDescription: desc)
            assertEqual(instrument.outputBusses.count, 1, "Instrument must have 1 output bus")
            assertEqual(instrument.inputBusses.count, 0, "Instrument must have 0 input busses")

            try instrument.allocateRenderResources()

            // Render block test. The instrument renderer supports a single
            // non-interleaved output buffer, which is sufficient to verify that
            // a Note On produces audio without relying on SDK-specific tuple
            // layout for AudioBufferList.mBuffers.
            let renderBlock = instrument.internalRenderBlock
            var flags: AudioUnitRenderActionFlags = []
            var timestamp = AudioTimeStamp()
            timestamp.mSampleTime = 0
            timestamp.mFlags = .sampleTimeValid

            let frameCount: UInt32 = 128
            var leftBuffer = [Float](repeating: 0, count: Int(frameCount))

            leftBuffer.withUnsafeMutableBufferPointer { leftPtr in
                var abl = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: frameCount * UInt32(MemoryLayout<Float>.size),
                        mData: leftPtr.baseAddress
                    )
                )

                // Create simulated MIDI Note On event
                var midiEvent = AURenderEvent()
                midiEvent.head.eventType = .MIDI
                midiEvent.head.eventSampleTime = 0
                midiEvent.MIDI.data = (0x90, 60, 100)
                midiEvent.MIDI.length = 3

                let status = withUnsafePointer(to: &midiEvent) { eventPtr in
                    renderBlock(&flags, &timestamp, frameCount, 0, &abl, eventPtr, nil)
                }
                assertEqual(status, noErr, "Render block must return noErr")
            }

            // Check that audio was generated
            let maxAudioSample = leftBuffer.map { abs($0) }.max() ?? 0
            assertTrue(maxAudioSample > 0.0001, "Poly synth render block must generate audio on Note On")

            // Full state serialization test
            let state = instrument.fullState
            assertNotNil(state, "Full state must serialize")
            assertTrue(state?["XPadParameters"] != nil, "Full state must contain parameter dictionary")

            instrument.deallocateRenderResources()
        } catch {
            assertTrue(false, "AUv3 Instrument instantiation failed: \(error)")
        }

        // 3. AUv3 MIDI FX Instantiation & Processing Test
        do {
            let desc = XPadPluginRegistrar.midiFXComponentDescription
            let midiFX = try XPadAUMIDIFX(componentDescription: desc)
            assertEqual(midiFX.outputBusses.count, 0, "MIDI FX has 0 audio output busses")
            assertEqual(midiFX.inputBusses.count, 0, "MIDI FX has 0 audio input busses")

            var generatedMIDIEvents: [[UInt8]] = []
            midiFX.midiOutputEventBlock = { _, _, length, data in
                let bytes = Array(UnsafeBufferPointer(start: data, count: length))
                generatedMIDIEvents.append(bytes)
                return noErr
            }

            try midiFX.allocateRenderResources()
            let renderBlock = midiFX.internalRenderBlock
            var flags: AudioUnitRenderActionFlags = []
            var timestamp = AudioTimeStamp()
            timestamp.mSampleTime = 0

            // Send Note On to MIDI FX
            var midiInEvent = AURenderEvent()
            midiInEvent.head.eventType = .MIDI
            midiInEvent.MIDI.data = (0x90, 62, 100) // D4
            midiInEvent.MIDI.length = 3

            var emptyAbl = AudioBufferList()
            withUnsafePointer(to: &midiInEvent) { eventPtr in
                _ = renderBlock(&flags, &timestamp, 64, 0, &emptyAbl, eventPtr, nil)
            }

            assertTrue(generatedMIDIEvents.count >= 3, "MIDI FX must output voice-led chord note events for input note")
            assertTrue(generatedMIDIEvents.allSatisfy { $0[0] == 0x90 }, "Generated events must be Note On")

            midiFX.deallocateRenderResources()
        } catch {
            assertTrue(false, "AUv3 MIDI FX instantiation failed: \(error)")
        }

        // 4. VST3 Bridge Parameter Mapping Test
        let vstBridge = VST3Bridge.shared
        assertNotNil(vstBridge.parameterInfos[100], "VST3 Master Volume parameter must exist")
        if let cutoffInfo = vstBridge.parameterInfos[200] {
            assertEqual(cutoffInfo.minValue, 20.0, "VST3 Cutoff min")
            assertEqual(cutoffInfo.maxValue, 20000.0, "VST3 Cutoff max")
            let normalized = cutoffInfo.plainToNormalized(10010.0)
            assertTrue(abs(normalized - 0.5) < 0.01, "Plain to normalized conversion")
            let plain = cutoffInfo.normalizedToPlain(0.5)
            assertTrue(abs(plain - 10010.0) < 1.0, "Normalized to plain conversion")
        }
    }
}
