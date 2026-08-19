import Foundation
import XPadCore
import XPadTheory

/// Practice lesson categories for organization and difficulty progression
public enum LessonCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case fundamentals = "Fundamentals"
    case diatonicProgressions = "Diatonic Progressions"
    case jazzHarmony = "Jazz Harmony"
    case modalInterchange = "Modal Interchange"
    case voiceLeading = "Voice Leading"
    case advancedConcepts = "Advanced Concepts"
    
    public var id: String { rawValue }
}

/// Difficulty levels for progressive learning
public enum LessonDifficulty: String, CaseIterable, Identifiable, Codable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    public var id: String { rawValue }
    
    public var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .expert: return 3
        }
    }
}

/// Individual step within a practice lesson
public struct PracticeStep: Identifiable, Codable, Sendable {
    public let id: UUID
    public let instruction: String
    public let expectedChord: Chord
    public let durationBeats: Double
    public let hint: String?
    public let harmonicContext: String?
    
    public init(
        id: UUID = UUID(),
        instruction: String,
        expectedChord: Chord,
        durationBeats: Double = 4.0,
        hint: String? = nil,
        harmonicContext: String? = nil
    ) {
        self.id = id
        self.instruction = instruction
        self.expectedChord = expectedChord
        self.durationBeats = durationBeats
        self.hint = hint
        self.harmonicContext = harmonicContext
    }
}

/// Complete practice lesson with metadata and steps
public struct PracticeLesson: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: LessonCategory
    public let difficulty: LessonDifficulty
    public let key: PitchClass
    public let scale: Scale
    public let steps: [PracticeStep]
    public let estimatedDurationMinutes: Int
    public let learningObjectives: [String]
    
    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: LessonCategory,
        difficulty: LessonDifficulty,
        key: PitchClass,
        scale: Scale,
        steps: [PracticeStep],
        estimatedDurationMinutes: Int = 5,
        learningObjectives: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.key = key
        self.scale = scale
        self.steps = steps
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.learningObjectives = learningObjectives
    }
    
    /// Total duration in beats
    public var totalDurationBeats: Double {
        steps.reduce(0) { $0 + $1.durationBeats }
    }
}

/// Challenge mode types for gamified practice
public enum ChallengeType: String, CaseIterable, Identifiable, Codable, Sendable {
    case guessNextChord = "Guess Next Chord"
    case voiceLeadingOptimization = "Voice Leading Optimization"
    case modulationDetection = "Modulation Detection"
    case speedAccuracy = "Speed & Accuracy"
    case harmonicTension = "Harmonic Tension"
    
    public var id: String { rawValue }
}

/// Challenge configuration for gamified practice
public struct PracticeChallenge: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: ChallengeType
    public let title: String
    public let description: String
    public let timeLimitSeconds: Int?
    public let targetAccuracy: Double
    public let baseProgression: Progression
    
    public init(
        id: UUID = UUID(),
        type: ChallengeType,
        title: String,
        description: String,
        timeLimitSeconds: Int? = nil,
        targetAccuracy: Double = 0.8,
        baseProgression: Progression
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.timeLimitSeconds = timeLimitSeconds
        self.targetAccuracy = targetAccuracy
        self.baseProgression = baseProgression
    }
}

/// Result of a single practice step attempt
public struct StepResult: Identifiable, Codable, Sendable {
    public let id: UUID
    public let stepId: UUID
    public let playedChord: Chord
    public let isCorrect: Bool
    public let timingAccuracy: Double // 0.0 to 1.0
    public let responseTimeSeconds: Double
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        stepId: UUID,
        playedChord: Chord,
        isCorrect: Bool,
        timingAccuracy: Double,
        responseTimeSeconds: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stepId = stepId
        self.playedChord = playedChord
        self.isCorrect = isCorrect
        self.timingAccuracy = max(0, min(1, timingAccuracy))
        self.responseTimeSeconds = responseTimeSeconds
        self.timestamp = timestamp
    }
}

/// Overall practice session results
public struct PracticeSessionResult: Identifiable, Codable, Sendable {
    public let id: UUID
    public let lessonId: UUID
    public let startTime: Date
    public let endTime: Date
    public let stepResults: [StepResult]
    public let overallAccuracy: Double
    public let averageResponseTime: Double
    public let completed: Bool
    
    public init(
        id: UUID = UUID(),
        lessonId: UUID,
        startTime: Date,
        endTime: Date,
        stepResults: [StepResult],
        overallAccuracy: Double,
        averageResponseTime: Double,
        completed: Bool
    ) {
        self.id = id
        self.lessonId = lessonId
        self.startTime = startTime
        self.endTime = endTime
        self.stepResults = stepResults
        self.overallAccuracy = max(0, min(1, overallAccuracy))
        self.averageResponseTime = averageResponseTime
        self.completed = completed
    }
    
    /// Duration of the practice session
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// Number of correctly completed steps
    public var correctStepsCount: Int {
        stepResults.filter { $0.isCorrect }.count
    }
    
    /// Percentage of steps completed correctly
    public var completionPercentage: Double {
        guard !stepResults.isEmpty else { return 0 }
        return Double(correctStepsCount) / Double(stepResults.count)
    }
}

// MARK: - Factory Presets

extension PracticeLesson {
    /// Creates factory preset lessons for common harmonic progressions
    public static func factoryPresets() -> [PracticeLesson] {
        [
            iiVIMajorLesson(),
            iiVIMinorLesson(),
            circleOfFifthsLesson(),
            jazzIIVIviLesson(),
            popProgressionLesson(),
            voiceLeadingLesson()
        ]
    }
    
    private static func iiVIMajorLesson() -> PracticeLesson {
        let key = PitchClass.c
        let scale = Scale(root: key, type: .major)
        
        let steps = [
            PracticeStep(
                instruction: "Start on the tonic (I) chord",
                expectedChord: Chord(root: key, quality: .major),
                hint: "This is your home base - the most stable chord",
                harmonicContext: "Tonic"
            ),
            PracticeStep(
                instruction: "Move to the supertonic (ii) chord",
                expectedChord: Chord(root: key.transposed(by: 2), quality: .minor),
                hint: "The ii chord sets up movement toward V",
                harmonicContext: "Pre-Dominant"
            ),
            PracticeStep(
                instruction: "Resolve to the dominant (V) chord",
                expectedChord: Chord(root: key.transposed(by: 7), quality: .major),
                hint: "The V chord creates tension that wants to resolve",
                harmonicContext: "Dominant"
            ),
            PracticeStep(
                instruction: "Return home to tonic (I)",
                expectedChord: Chord(root: key, quality: .major),
                hint: "Feel the resolution back to stability",
                harmonicContext: "Tonic"
            )
        ]
        
        return PracticeLesson(
            title: "ii-V-I in Major",
            description: "Learn the most important chord progression in Western music. This progression creates tension and resolution that forms the backbone of countless songs.",
            category: .fundamentals,
            difficulty: .beginner,
            key: key,
            scale: scale,
            steps: steps,
            estimatedDurationMinutes: 3,
            learningObjectives: [
                "Understand the functional roles of I, ii, and V chords",
                "Practice smooth voice leading between chord changes",
                "Feel the natural tension and resolution of the ii-V-I progression"
            ]
        )
    }
    
    private static func iiVIMinorLesson() -> PracticeLesson {
        let key = PitchClass.a
        let scale = Scale(root: key, type: .naturalMinor)
        
        let steps = [
            PracticeStep(
                instruction: "Start on the minor tonic (i)",
                expectedChord: Chord(root: key, quality: .minor),
                hint: "The i chord in minor has a darker quality",
                harmonicContext: "Tonic"
            ),
            PracticeStep(
                instruction: "Move to the diminished (ii°) chord",
                expectedChord: Chord(root: key.transposed(by: 2), quality: .diminished),
                hint: "The ii° chord is even more tense than major ii",
                harmonicContext: "Pre-Dominant"
            ),
            PracticeStep(
                instruction: "Go to the dominant (V) chord",
                expectedChord: Chord(root: key.transposed(by: 7), quality: .major),
                hint: "In minor, V is often major for stronger resolution",
                harmonicContext: "Dominant"
            ),
            PracticeStep(
                instruction: "Resolve back to minor tonic (i)",
                expectedChord: Chord(root: key, quality: .minor),
                hint: "Notice the darker resolution compared to major",
                harmonicContext: "Tonic"
            )
        ]
        
        return PracticeLesson(
            title: "ii-V-I in Minor",
            description: "Explore the minor key version of the essential ii-V-I progression. Learn how the altered chord qualities create a different emotional landscape.",
            category: .fundamentals,
            difficulty: .intermediate,
            key: key,
            scale: scale,
            steps: steps,
            estimatedDurationMinutes: 4,
            learningObjectives: [
                "Understand chord quality differences in minor keys",
                "Practice the emotional contrast between major and minor",
                "Master the ii°-V-i progression"
            ]
        )
    }
    
    private static func circleOfFifthsLesson() -> PracticeLesson {
        let key = PitchClass.c
        let scale = Scale(root: key, type: .major)
        
        let steps = [
            PracticeStep(
                instruction: "Start on C major (I)",
                expectedChord: Chord(root: .c, quality: .major),
                hint: "Begin at the top of the circle",
                harmonicContext: "Tonic"
            ),
            PracticeStep(
                instruction: "Move down a fifth to F major (IV)",
                expectedChord: Chord(root: .f, quality: .major),
                hint: "Moving down a fifth is the same as up a fourth",
                harmonicContext: "Subdominant"
            ),
            PracticeStep(
                instruction: "Continue to Bb major",
                expectedChord: Chord(root: .aSharp, quality: .major),
                hint: "Each step moves you further from the home key",
                harmonicContext: "Chromatic Mediant"
            ),
            PracticeStep(
                instruction: "Move to Eb major",
                expectedChord: Chord(root: .dSharp, quality: .major),
                hint: "Notice how the tonal center shifts",
                harmonicContext: "Chromatic Mediant"
            ),
            PracticeStep(
                instruction: "Return to C major (I)",
                expectedChord: Chord(root: .c, quality: .major),
                hint: "Complete the circle back home",
                harmonicContext: "Tonic"
            )
        ]
        
        return PracticeLesson(
            title: "Circle of Fifths Journey",
            description: "Travel through the circle of fifths and understand how root motion by perfect fifths creates strong harmonic movement. This pattern appears throughout jazz and classical music.",
            category: .diatonicProgressions,
            difficulty: .intermediate,
            key: key,
            scale: scale,
            steps: steps,
            estimatedDurationMinutes: 5,
            learningObjectives: [
                "Understand circle of fifths root motion",
                "Practice navigating through distant keys",
                "Learn to recognize sequential harmonic patterns"
            ]
        )
    }
    
    private static func jazzIIVIviLesson() -> PracticeLesson {
        let key = PitchClass.c
        let scale = Scale(root: key, type: .major)
        
        let steps = [
            PracticeStep(
                instruction: "Start with ii-V-I: Dm, G, C",
                expectedChord: Chord(root: .c, quality: .major),
                durationBeats: 12.0,
                hint: "The classic jazz turnaround foundation",
                harmonicContext: "Complete ii-V-I"
            ),
            PracticeStep(
                instruction: "Add the deceptive vi: Am",
                expectedChord: Chord(root: .a, quality: .minor),
                hint: "The vi chord creates a deceptive resolution",
                harmonicContext: "Deceptive Resolution"
            ),
            PracticeStep(
                instruction: "Full progression: ii-V-I-vi",
                expectedChord: Chord(root: .a, quality: .minor),
                durationBeats: 16.0,
                hint: "This is the backbone of many jazz standards",
                harmonicContext: "Jazz Turnaround"
            )
        ]
        
        return PracticeLesson(
            title: "Jazz ii-V-I-vi Turnaround",
            description: "Master the essential jazz turnaround progression. This four-chord pattern appears in countless jazz standards and provides the foundation for improvisation.",
            category: .jazzHarmony,
            difficulty: .intermediate,
            key: key,
            scale: scale,
            steps: steps,
            estimatedDurationMinutes: 6,
            learningObjectives: [
                "Memorize the jazz turnaround progression",
                "Understand the function of the deceptive vi chord",
                "Practice smooth transitions between all four chords"
            ]
        )
    }
    
    private static func popProgressionLesson() -> PracticeLesson {
        let key = PitchClass.c
        let scale = Scale(root: key, type: .major)
        
        let steps = [
            PracticeStep(
                instruction: "Start with I - V: C to G",
                expectedChord: Chord(root: .g, quality: .major),
                hint: "The most basic rock and pop progression",
                harmonicContext: "I-V Movement"
            ),
            PracticeStep(
                instruction: "Add vi: Am to create I-V-vi",
                expectedChord: Chord(root: .a, quality: .minor),
                hint: "The vi adds emotional depth",
                harmonicContext: "I-V-vi"
            ),
            PracticeStep(
                instruction: "Complete with IV: F for I-V-vi-IV",
                expectedChord: Chord(root: .f, quality: .major),
                hint: "The 'axis of awesome' progression",
                harmonicContext: "Pop Progression"
            ),
            PracticeStep(
                instruction: "Practice the full progression repeatedly",
                expectedChord: Chord(root: .c, quality: .major),
                durationBeats: 16.0,
                hint: "This progression appears in hundreds of hit songs",
                harmonicContext: "Complete Pop Progression"
            )
        ]
        
        return PracticeLesson(
            title: "Pop Music Progressions",
            description: "Learn the most common chord progressions in popular music. The I-V-vi-IV progression appears in countless hit songs across multiple decades.",
            category: .diatonicProgressions,
            difficulty: .beginner,
            key: key,
            scale: scale,
            steps: steps,
            estimatedDurationMinutes: 4,
            learningObjectives: [
                "Master the I-V-vi-IV pop progression",
                "Recognize this pattern in popular music",
                "Practice smooth chord changes for song accompaniment"
            ]
        )
    }
    
    private static func voiceLeadingLesson() -> PracticeLesson {
        let key = PitchClass.c
        let scale = Scale(root: key, type: .major)
        
        let steps = [
            PracticeStep(
                instruction: "Play C major (I) - notice the voicing",
                expectedChord: Chord(root: .c, quality: .major),
                hint: "Pay attention to which notes you're actually playing",
                harmonicContext: "Starting Voicing"
            ),
            PracticeStep(
                instruction: "Move to F major (IV) with minimal motion",
                expectedChord: Chord(root: .f, quality: .major),
                hint: "Try to keep common tones (C) in the same voice",
                harmonicContext: "Voice Leading Challenge"
            ),
            PracticeStep(
                instruction: "Go to G major (V) smoothly",
                expectedChord: Chord(root: .g, quality: .major),
                hint: "Maintain smooth voice movement between chord changes",
                harmonicContext: "Voice Leading Challenge"
            ),
            PracticeStep(
                instruction: "Return to C major (I) elegantly",
                expectedChord: Chord(root: .c, quality: .major),
                hint: "Notice how smooth voice leading creates better musical flow",
                harmonicContext: "Voice Leading Challenge"
            )
        ]
        
        return PracticeLesson(
            title: "Voice Leading Fundamentals",
            description: "Learn the art of smooth voice leading - the practice of moving individual chord voices as little as possible between harmonic changes. This creates more musical and professional-sounding progressions.",
            category: .voiceLeading,
            difficulty: .intermediate,
            key: key,
            scale: scale,
            steps: steps,
            estimatedDurationMinutes: 5,
            learningObjectives: [
                "Understand the concept of common tones",
                "Practice minimizing voice movement between chords",
                "Develop smoother chord transitions"
            ]
        )
    }
}

extension PracticeChallenge {
    /// Create factory preset challenges
    public static func factoryPresets() -> [PracticeChallenge] {
        let progression = Progression(scale: Scale(root: .c, type: .major))
        
        return [
            PracticeChallenge(
                type: .guessNextChord,
                title: "Chord Prediction",
                description: "Guess the next chord in the progression based on harmonic context",
                timeLimitSeconds: 30,
                targetAccuracy: 0.7,
                baseProgression: progression
            ),
            PracticeChallenge(
                type: .voiceLeadingOptimization,
                title: "Smooth Voice Leading",
                description: "Achieve the smoothest possible voice leading between chord changes",
                timeLimitSeconds: 60,
                targetAccuracy: 0.8,
                baseProgression: progression
            ),
            PracticeChallenge(
                type: .speedAccuracy,
                title: "Speed Round",
                description: "Complete the progression as quickly and accurately as possible",
                timeLimitSeconds: 45,
                targetAccuracy: 0.85,
                baseProgression: progression
            )
        ]
    }
}