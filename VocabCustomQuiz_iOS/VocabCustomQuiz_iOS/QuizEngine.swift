import Foundation
import SwiftUI
import AVFoundation
import AudioToolbox
import Combine

// Model for a single vocabulary item
struct VocabItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var word: String
    var meaning: String
    var distractor1: String?
    var distractor2: String?
    var distractor3: String?
    var incorrectCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, word, meaning, distractor1, distractor2, distractor3, incorrectCount
    }
    
    // Custom decoder to supply UUID if missing in old stored data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.word = try container.decode(String.self, forKey: .word)
        self.meaning = try container.decode(String.self, forKey: .meaning)
        self.distractor1 = try container.decodeIfPresent(String.self, forKey: .distractor1)
        self.distractor2 = try container.decodeIfPresent(String.self, forKey: .distractor2)
        self.distractor3 = try container.decodeIfPresent(String.self, forKey: .distractor3)
        self.incorrectCount = try container.decodeIfPresent(Int.self, forKey: .incorrectCount) ?? 0
    }
    
    init(word: String, meaning: String, distractor1: String? = nil, distractor2: String? = nil, distractor3: String? = nil, incorrectCount: Int = 0) {
        self.id = UUID()
        self.word = word
        self.meaning = meaning
        self.distractor1 = distractor1
        self.distractor2 = distractor2
        self.distractor3 = distractor3
        self.incorrectCount = incorrectCount
    }
}

// Model representing a Folder/Deck of Vocabulary lists
struct VocabDeck: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var vocabList: [VocabItem]
}

enum QuizMode: String, Codable {
    case multipleChoice = "4択クイズ"
    case flashcard = "単語帳"
}

enum RangeMode: String, Codable {
    case byNumber = "番号で指定"
    case randomCount = "ランダムに出題"
    case incorrectOnly = "苦手な単語のみ"
}

// Model for recorded quiz answers
struct QuizAnswer: Identifiable {
    var id = UUID()
    var word: String
    var meaning: String
    var chosen: String
    var isCorrect: Bool
    var timeSpent: Double
}

class QuizEngine: ObservableObject {
    // List of Decks (Folders)
    @Published var decks: [VocabDeck] = []
    
    //出題形式
    @Published var quizMode: QuizMode = .multipleChoice
    
    //出題範囲モード
    @Published var rangeMode: RangeMode = .byNumber
    
    //ランダム出題問題数
    @Published var randomQuestionCount: Int = 20
    
    // Active Selected Deck ID
    @Published var selectedDeckId: UUID? = nil {
        didSet {
            // Adjust range bounds when changing decks
            if let deck = selectedDeck {
                self.rangeStart = 1
                self.rangeEnd = max(1, min(20, deck.vocabList.count))
            }
        }
    }
    
    // Active test questions
    @Published var activeQuizList: [VocabItem] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var quizAnswers: [QuizAnswer] = []
    @Published var isQuizActive: Bool = false
    
    // Current options generated for active question
    @Published var currentOptions: [Option] = []
    
    // Timer details
    @Published var timeLeft: Double = 1.0 // 1.0 to 0.0 representation for SwiftUI ProgressView
    private var timer: Timer?
    private var timerDuration: Double = 10.0 // 10 seconds limit
    private var timeElapsedInQuestion: Double = 0.0
    private var questionStartTime: Date = Date()
    
    // Test Configurations
    @Published var rangeStart: Int = 1
    @Published var rangeEnd: Int = 20
    @Published var isShuffle: Bool = true
    @Published var isTimerEnabled: Bool = true
    @Published var isAudioEnabled: Bool = true
    
    // TTS voice speech synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Struct representing an answer option
    struct Option: Identifiable, Equatable {
        var id = UUID()
        var text: String
        var isCorrect: Bool
        var status: OptionStatus = .normal
    }
    
    enum OptionStatus {
        case normal
        case correct
        case incorrect
        case faded
    }
    
    // Getter for currently selected deck
    var selectedDeck: VocabDeck? {
        guard let id = selectedDeckId else { return nil }
        return decks.first(where: { $0.id == id })
    }
    
    // Disk Persistence location
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("vocab_decks.json")
    }
    
    // Default 100 verbs for initial load
    static let defaultVocab: [VocabItem] = [
        VocabItem(word: "include", meaning: "を含む"),
        VocabItem(word: "associate", meaning: "を関連づける"),
        VocabItem(word: "concern", meaning: "を心配させる"),
        VocabItem(word: "improve", meaning: "を向上させる"),
        VocabItem(word: "provide", meaning: "を提供する"),
        VocabItem(word: "develop", meaning: "を開発する"),
        VocabItem(word: "increase", meaning: "を増やす"),
        VocabItem(word: "decrease", meaning: "を減らす"),
        VocabItem(word: "achieve", meaning: "を達成する"),
        VocabItem(word: "require", meaning: "を必要とする"),
        VocabItem(word: "produce", meaning: "を生産する"),
        VocabItem(word: "prevent", meaning: "を妨げる"),
        VocabItem(word: "determine", meaning: "を決定する"),
        VocabItem(word: "encourage", meaning: "を励ます"),
        VocabItem(word: "establish", meaning: "を設立する"),
        VocabItem(word: "identify", meaning: "を特定する"),
        VocabItem(word: "prepare", meaning: "を準備する"),
        VocabItem(word: "reduce", meaning: "を減らす"),
        VocabItem(word: "support", meaning: "を支持する"),
        VocabItem(word: "maintain", meaning: "を維持する"),
        VocabItem(word: "expect", meaning: "を期待する"),
        VocabItem(word: "propose", meaning: "を提案する"),
        VocabItem(word: "consider", meaning: "をよく考える"),
        VocabItem(word: "recognize", meaning: "を認める"),
        VocabItem(word: "suggest", meaning: "を提案する"),
        VocabItem(word: "allow", meaning: "を許す"),
        VocabItem(word: "remain", meaning: "ままでいる"),
        VocabItem(word: "contain", meaning: "を含む"),
        VocabItem(word: "perform", meaning: "を行う"),
        VocabItem(word: "replace", meaning: "に取って代わる"),
        VocabItem(word: "realize", meaning: "を悟る"),
        VocabItem(word: "discover", meaning: "を発見する"),
        VocabItem(word: "protect", meaning: "を保護する"),
        VocabItem(word: "destroy", meaning: "を破壊する"),
        VocabItem(word: "observe", meaning: "を観察する"),
        VocabItem(word: "mention", meaning: "に言及する"),
        VocabItem(word: "compare", meaning: "を比較する"),
        VocabItem(word: "describe", meaning: "を描写する"),
        VocabItem(word: "explain", meaning: "を説明する"),
        VocabItem(word: "discuss", meaning: "について話し合う"),
        VocabItem(word: "focus", meaning: "を集中させる"),
        VocabItem(word: "express", meaning: "を表現する"),
        VocabItem(word: "publish", meaning: "を出版する"),
        VocabItem(word: "behave", meaning: "振る舞う"),
        VocabItem(word: "attend", meaning: "に出席する"),
        VocabItem(word: "survive", meaning: "生き残る"),
        VocabItem(word: "respond", meaning: "反応する"),
        VocabItem(word: "argue", meaning: "と主張する"),
        VocabItem(word: "refuse", meaning: "を拒む"),
        VocabItem(word: "admit", meaning: "を認める"),
        VocabItem(word: "deny", meaning: "を否定する"),
        VocabItem(word: "prefer", meaning: "を好む"),
        VocabItem(word: "demand", meaning: "を要求する"),
        VocabItem(word: "request", meaning: "を要請する"),
        VocabItem(word: "receive", meaning: "を受け取る"),
        VocabItem(word: "accept", meaning: "を受け入れる"),
        VocabItem(word: "obtain", meaning: "を手に入れる"),
        VocabItem(word: "create", meaning: "を創造する"),
        VocabItem(word: "design", meaning: "を設計する"),
        VocabItem(word: "invent", meaning: "を発明する"),
        VocabItem(word: "experience", meaning: "を経験する"),
        VocabItem(word: "believe", meaning: "を信じる"),
        VocabItem(word: "know", meaning: "を知っている"),
        VocabItem(word: "remember", meaning: "を覚えている"),
        VocabItem(word: "forget", meaning: "を忘れる"),
        VocabItem(word: "understand", meaning: "を理解する"),
        VocabItem(word: "learn", meaning: "を学ぶ"),
        VocabItem(word: "teach", meaning: "を教える"),
        VocabItem(word: "practice", meaning: "を練習する"),
        VocabItem(word: "repeat", meaning: "を繰り返す"),
        VocabItem(word: "translate", meaning: "を翻訳する"),
        VocabItem(word: "speak", meaning: "を話す"),
        VocabItem(word: "read", meaning: "を読む"),
        VocabItem(word: "write", meaning: "を書く"),
        VocabItem(word: "listen", meaning: "を聴く"),
        VocabItem(word: "hear", meaning: "が聞こえる"),
        VocabItem(word: "see", meaning: "が見える"),
        VocabItem(word: "look", meaning: "を見る"),
        VocabItem(word: "watch", meaning: "を見守る"),
        VocabItem(word: "notice", meaning: "に気づく"),
        VocabItem(word: "feel", meaning: "を感じる"),
        VocabItem(word: "think", meaning: "と思う"),
        VocabItem(word: "decide", meaning: "を決心する"),
        VocabItem(word: "choose", meaning: "を選ぶ"),
        VocabItem(word: "select", meaning: "を精選する"),
        VocabItem(word: "elect", meaning: "を選挙する"),
        VocabItem(word: "like", meaning: "を好む"),
        VocabItem(word: "love", meaning: "を愛する"),
        VocabItem(word: "hate", meaning: "を憎む"),
        VocabItem(word: "fear", meaning: "を恐れる"),
        VocabItem(word: "worry", meaning: "を心配する"),
        VocabItem(word: "mind", meaning: "を気にする"),
        VocabItem(word: "care", meaning: "を気にかける"),
        VocabItem(word: "wish", meaning: "を望む"),
        VocabItem(word: "hope", meaning: "を望む"),
        VocabItem(word: "want", meaning: "を欲する")
    ]
    
    init() {
        loadDecksFromDisk()
    }
    
    // ==============================================
    // PERSISTENCE ENGINE
    // ==============================================
    
    func saveDecksToDisk() {
        do {
            let data = try JSONEncoder().encode(decks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save decks: \(error.localizedDescription)")
        }
    }
    
    func loadDecksFromDisk() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([VocabDeck].self, from: data)
                self.decks = decoded
            } else {
                // Initial load: create a sample deck
                let sampleDeck = VocabDeck(name: "デフォルト単語帳 (100語)", vocabList: QuizEngine.defaultVocab)
                self.decks = [sampleDeck]
                saveDecksToDisk()
            }
        } catch {
            print("Failed to load decks: \(error.localizedDescription)")
            // Fallback safe state
            let sampleDeck = VocabDeck(name: "デフォルト単語帳 (100語)", vocabList: QuizEngine.defaultVocab)
            self.decks = [sampleDeck]
        }
        
        // Auto select first if none is selected
        if selectedDeckId == nil, let first = decks.first {
            selectedDeckId = first.id
        }
    }
    
    // ==============================================
    // DECK MANAGER OPERATIONS
    // ==============================================
    
    func createDeck(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "新規単語帳" : cleanName
        
        let newDeck = VocabDeck(name: finalName, vocabList: [])
        decks.append(newDeck)
        selectedDeckId = newDeck.id
        saveDecksToDisk()
    }
    
    func deleteDeck(id: UUID) {
        decks.removeAll { $0.id == id }
        if selectedDeckId == id {
            selectedDeckId = decks.first?.id
        }
        saveDecksToDisk()
    }
    
    func renameDeck(id: UUID, newName: String) {
        guard let idx = decks.firstIndex(where: { $0.id == id }) else { return }
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.isEmpty {
            decks[idx].name = cleanName
            saveDecksToDisk()
        }
    }
    
    // =image templates
    func getTemplateCSVContent() -> String {
        return """
        word,meaning,distractor1,distractor2,distractor3
        include,を含める,を除外する,を分割する,を関連づける
        improve,を向上させる,を低下させる,を準備する,を保護する
        prevent,を妨げる,を促す,を受け取る,を説明する
        maintain,を維持する,を放棄する,を繰り返す,を信じる
        obtain,を手に入れる,を失う,を恐れる,を心配する
        """
    }
    
    // ==============================================
    // WORDS EDITING ENGINE
    // ==============================================
    
    func addWordToSelectedDeck(word: String, meaning: String) {
        guard let deckId = selectedDeckId, let idx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanWord.isEmpty && !cleanMeaning.isEmpty else { return }
        
        let newItem = VocabItem(word: cleanWord, meaning: cleanMeaning)
        decks[idx].vocabList.append(newItem)
        
        // Re-adjust ranges
        self.rangeEnd = decks[idx].vocabList.count
        
        saveDecksToDisk()
    }
    
    func deleteWordFromSelectedDeck(itemId: UUID) {
        guard let deckId = selectedDeckId, let idx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        decks[idx].vocabList.removeAll { $0.id == itemId }
        
        // Re-adjust ranges
        self.rangeStart = max(1, min(self.rangeStart, decks[idx].vocabList.count))
        self.rangeEnd = max(1, min(self.rangeEnd, decks[idx].vocabList.count))
        
        saveDecksToDisk()
    }
    
    func incrementIncorrectCount(for itemId: UUID) {
        guard let deckId = selectedDeckId, let deckIdx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        if let wordIdx = decks[deckIdx].vocabList.firstIndex(where: { $0.id == itemId }) {
            decks[deckIdx].vocabList[wordIdx].incorrectCount += 1
            saveDecksToDisk()
        }
    }
    
    func resetIncorrectCount(for itemId: UUID) {
        guard let deckId = selectedDeckId, let deckIdx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        if let wordIdx = decks[deckIdx].vocabList.firstIndex(where: { $0.id == itemId }) {
            decks[deckIdx].vocabList[wordIdx].incorrectCount = 0
            saveDecksToDisk()
        }
    }
    
    func resetAllIncorrectCountsInSelectedDeck() {
        guard let deckId = selectedDeckId, let deckIdx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        for wordIdx in 0..<decks[deckIdx].vocabList.count {
            decks[deckIdx].vocabList[wordIdx].incorrectCount = 0
        }
        saveDecksToDisk()
    }
    
    func resetSelectedDeckToDefault() {
        guard let deckId = selectedDeckId, let idx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        decks[idx].vocabList = QuizEngine.defaultVocab
        self.rangeStart = 1
        self.rangeEnd = QuizEngine.defaultVocab.count
        saveDecksToDisk()
    }
    
    // Import and parse CSV String directly into active deck
    func importCSVIntoSelectedDeck(text: String) -> Bool {
        guard let deckId = selectedDeckId, let idx = decks.firstIndex(where: { $0.id == deckId }) else { return false }
        
        var tempItems: [VocabItem] = []
        let rows = parseCSVRows(text: text)
        for row in rows {
            if row.count < 2 { continue }
            let word = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip headers or empty fields
            if word.isEmpty || meaning.isEmpty { continue }
            if word.lowercased() == "word" || word == "単語" { continue }
            
            var item = VocabItem(word: word, meaning: meaning)
            if row.count > 2 { item.distractor1 = row[2].trimmingCharacters(in: .whitespacesAndNewlines) }
            if row.count > 3 { item.distractor2 = row[3].trimmingCharacters(in: .whitespacesAndNewlines) }
            if row.count > 4 { item.distractor3 = row[4].trimmingCharacters(in: .whitespacesAndNewlines) }
            
            tempItems.append(item)
        }
        
        if !tempItems.isEmpty {
            decks[idx].vocabList.append(contentsOf: tempItems)
            self.rangeStart = 1
            self.rangeEnd = decks[idx].vocabList.count
            saveDecksToDisk()
            return true
        }
        return false
    }
    
    // Robust CSV Row splitter (supporting double quotes)
    private func parseCSVRows(text: String) -> [[String]] {
        var result: [[String]] = []
        var currentRow: [String] = [""]
        var inQuotes = false
        
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == "," && !inQuotes {
                currentRow.append("")
            } else if (character == "\n" || character == "\r") && !inQuotes {
                if currentRow.count > 1 || !currentRow[0].isEmpty {
                    result.append(currentRow)
                }
                currentRow = [""]
            } else {
                currentRow[currentRow.count - 1].append(character)
            }
        }
        
        if currentRow.count > 1 || !currentRow[0].isEmpty {
            result.append(currentRow)
        }
        
        return result
    }
    
    // ==============================================
    // QUIZ GAMEPLAY CONTROL
    // ==============================================
    
    // Initialize Quiz Play
    func startQuiz() {
        guard let deck = selectedDeck else { return }
        
        var sliced: [VocabItem] = []
        if rangeMode == .byNumber {
            let startIdx = max(0, rangeStart - 1)
            let endIdx = min(deck.vocabList.count, rangeEnd)
            guard startIdx < endIdx else { return }
            sliced = Array(deck.vocabList[startIdx..<endIdx])
            if isShuffle {
                sliced.shuffle()
            }
        } else if rangeMode == .randomCount {
            let count = min(deck.vocabList.count, max(1, randomQuestionCount))
            sliced = Array(deck.vocabList.shuffled().prefix(count))
        } else { // incorrectOnly
            let failedWords = deck.vocabList.filter { $0.incorrectCount > 0 }
            sliced = failedWords
            if isShuffle {
                sliced.shuffle()
            }
        }
        
        self.activeQuizList = sliced
        self.currentQuestionIndex = 0
        self.score = 0
        self.quizAnswers = []
        self.isQuizActive = true
        
        loadQuestion()
    }
    
    // Load question at current index
    func loadQuestion() {
        guard isQuizActive else { return }
        guard currentQuestionIndex < activeQuizList.count else { return }
        guard let deck = selectedDeck else { return }
        
        let currentItem = activeQuizList[currentQuestionIndex]
        
        // Pronounce English word automatically
        speak(text: currentItem.word)
        
        // Generate options (correct + 3 distractors)
        var choices: [String] = [currentItem.meaning]
        
        if let d1 = currentItem.distractor1, let d2 = currentItem.distractor2, let d3 = currentItem.distractor3,
           !d1.isEmpty, !d2.isEmpty, !d3.isEmpty {
            choices.append(contentsOf: [d1, d2, d3])
        } else {
            // Dynamically pick 3 random distractors from rest of active deck vocabulary list
            let otherMeanings = deck.vocabList
                .filter { $0.meaning != currentItem.meaning }
                .map { $0.meaning }
            
            var selectedDistractors = Array(otherMeanings.shuffled().prefix(3))
            
            // Pad if not enough
            while selectedDistractors.count < 3 {
                selectedDistractors.append("（選択肢）")
            }
            
            choices.append(contentsOf: selectedDistractors)
        }
        
        // Map options and shuffle
        var optList = choices.enumerated().map { (index, text) in
            Option(text: text, isCorrect: index == 0)
        }
        optList.shuffle()
        
        self.currentOptions = optList
        self.questionStartTime = Date()
        
        // Start Countdown Timer
        if isTimerEnabled && quizMode == .multipleChoice {
            startTimeLimit()
        } else {
            self.timeLeft = 1.0
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimeLimit() {
        timer?.invalidate()
        self.timeLeft = 1.0
        self.timeElapsedInQuestion = 0.0
        
        let step = 0.05 // update progress every 50ms
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeElapsedInQuestion += step
            let remaining = max(0.0, 1.0 - (self.timeElapsedInQuestion / self.timerDuration))
            self.timeLeft = remaining
            
            if remaining <= 0 {
                self.timer?.invalidate()
                self.resolveAnswer(selectedOption: nil) // Timeout resolved
            }
        }
    }
    
    // Resolve selected choice
    func selectOption(optionId: UUID) {
        guard let idx = currentOptions.firstIndex(where: { $0.id == optionId }) else { return }
        resolveAnswer(selectedOption: currentOptions[idx])
    }
    
    func selectDontKnow() {
        resolveAnswer(selectedOption: nil)
    }
    
    // Resolve Flashcard Self-Assessment (Remembered vs Forgot)
    func resolveFlashcardAnswer(isCorrect: Bool) {
        timer?.invalidate()
        
        let elapsed = Date().timeIntervalSince(questionStartTime)
        let currentItem = activeQuizList[currentQuestionIndex]
        
        let chosenText = isCorrect ? "覚えている" : "覚えていない"
        
        // Play audio & haptics
        if isAudioEnabled {
            if isCorrect {
                playSystemSound(isCorrect: true)
                triggerHaptic(success: true)
            } else {
                playSystemSound(isCorrect: false)
                triggerHaptic(success: false)
            }
        }
        
        if isCorrect {
            score += 1
        } else {
            incrementIncorrectCount(for: currentItem.id)
        }
        
        // Save answers
        quizAnswers.append(QuizAnswer(word: currentItem.word, meaning: currentItem.meaning, chosen: chosenText, isCorrect: isCorrect, timeSpent: elapsed))
        
        // Wait 0.3s for smooth UI feedback transition, then go to next question
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            guard self.isQuizActive else { return }
            self.currentQuestionIndex += 1
            if self.currentQuestionIndex < self.activeQuizList.count {
                self.loadQuestion()
            }
        }
    }
    
    private func resolveAnswer(selectedOption: Option?) {
        timer?.invalidate()
        
        let elapsed = Date().timeIntervalSince(questionStartTime)
        let currentItem = activeQuizList[currentQuestionIndex]
        
        var isCorrect = false
        var chosenText = "わからない"
        
        if let option = selectedOption {
            chosenText = option.text
            isCorrect = option.isCorrect
        } else {
            chosenText = timeLeft <= 0 ? "(時間切れ)" : "わからない"
        }
        
        // Play audio & haptics
        if isAudioEnabled {
            if isCorrect {
                playSystemSound(isCorrect: true)
                triggerHaptic(success: true)
            } else {
                playSystemSound(isCorrect: false)
                triggerHaptic(success: false)
            }
        }
        
        if isCorrect {
            score += 1
        } else {
            incrementIncorrectCount(for: currentItem.id)
        }
        
        // Update Options Status for UI Feedback
        for idx in 0..<currentOptions.count {
            let opt = currentOptions[idx]
            if opt.isCorrect {
                currentOptions[idx].status = .correct
            } else if let selected = selectedOption, opt.id == selected.id && !selected.isCorrect {
                currentOptions[idx].status = .incorrect
            } else {
                currentOptions[idx].status = .faded
            }
        }
        
        // Save answers
        quizAnswers.append(QuizAnswer(word: currentItem.word, meaning: currentItem.meaning, chosen: chosenText, isCorrect: isCorrect, timeSpent: elapsed))
        
        // Wait 1.2s then load next question or finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            guard self.isQuizActive else { return }
            self.currentQuestionIndex += 1
            if self.currentQuestionIndex < self.activeQuizList.count {
                self.loadQuestion()
            } else {
                // Done! Will navigate to results screen in view
            }
        }
    }
    
    // Restart only incorrect words
    func retryIncorrectOnly() {
        let failed = quizAnswers.filter { !$0.isCorrect }.map { ans in
            VocabItem(word: ans.word, meaning: ans.meaning)
        }
        
        guard !failed.isEmpty else { return }
        
        var finalRetryList = failed
        if isShuffle {
            finalRetryList.shuffle()
        }
        
        self.activeQuizList = finalRetryList
        self.currentQuestionIndex = 0
        self.score = 0
        self.quizAnswers = []
        
        loadQuestion()
    }
    
    // Cancel timer and TTS voice, stop the quiz active state
    func stopQuiz() {
        self.isQuizActive = false
        timer?.invalidate()
        timer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // TTS voice speech synthesis helper
    func speak(text: String) {
        guard isAudioEnabled else { return }
        
        // Cancel ongoing utterances
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Standard speed
        speechSynthesizer.speak(utterance)
    }
    
    // System Tone Sound generator
    private func playSystemSound(isCorrect: Bool) {
        #if os(iOS)
        let soundID: SystemSoundID = isCorrect ? 1057 : 1053
        AudioServicesPlaySystemSound(soundID)
        #endif
    }
    
    // System Haptic generator
    private func triggerHaptic(success: Bool) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(success ? .success : .error)
        #endif
    }
}
