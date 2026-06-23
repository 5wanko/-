import SwiftUI
import UniformTypeIdentifiers

enum AppScreen {
    case deckList
    case setup
    case quiz
    case results
}

struct ContentView: View {
    @StateObject private var engine = QuizEngine()
    @State private var currentScreen: AppScreen = .deckList
    
    // File Importer state variables
    @State private var showFilePicker = false
    @State private var showImportAlert = false
    @State private var importAlertMsg = ""
    
    // Search filter state
    @State private var searchText = ""
    
    // UI Display States
    @State private var visibleWordCount = 50
    @State private var isFlipped = false
    
    // Create new deck dialog state
    @State private var showCreateDeckAlert = false
    @State private var newDeckName = ""
    
    // Add new word fields in manager
    @State private var newWord = ""
    @State private var newMeaning = ""
    @State private var isShowingWeakWordsSheet = false
    
    // Keyboard Focus State
    @FocusState private var isInputFocused: Bool
    
    // Color Palette matching Reference
    let blueHeader = Color(red: 0.0, green: 0.635, blue: 0.91)     // #00A2E8
    let brownPanel = Color(red: 0.69, green: 0.56, blue: 0.446)    // #B08E72
    let creamBg = Color(red: 0.976, green: 0.96, blue: 0.92)       // #F9F5EB
    let creamCard = Color(red: 0.98, green: 0.965, blue: 0.933)    // #FAF6EE
    let borderCol = Color(red: 0.898, green: 0.878, blue: 0.835)   // #E5E0D5
    let textDark = Color(red: 0.173, green: 0.122, blue: 0.082)    // #2C1F15
    let correctGreen = Color(red: 0.3, green: 0.85, blue: 0.39)    // #4CD964
    let incorrectRed = Color(red: 1.0, green: 0.23, blue: 0.188)   // #FF3B30
    
    var body: some View {
        ZStack {
            // Screen switching
            switch currentScreen {
            case .deckList:
                deckListScreen
                    .transition(.opacity)
            case .setup:
                setupScreen
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            case .quiz:
                quizScreen
                    .transition(.slide)
            case .results:
                resultsScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentScreen)
        .preferredColorScheme(.light) // Lock in light theme for beige aesthetic accuracy
    }
    
    // ==============================================
    // SCREEN 0: DECK/FOLDER LIST (NEW HOME SCREEN)
    // ==============================================
    var deckListScreen: some View {
        VStack(spacing: 0) {
            // Blue Header
            VStack(alignment: .leading, spacing: 2) {
                Text("単語帳 改")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white)
                Text("単語帳のフォルダー管理")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(blueHeader)
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Create New Folder Card
                    Button(action: {
                        showCreateDeckAlert = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                            Text("新しい単語帳を作成する")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(correctGreen)
                        .cornerRadius(12)
                        .shadow(color: correctGreen.opacity(0.2), radius: 5, y: 3)
                    }
                    
                    Text("単語帳一覧")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    // List of current decks
                    if engine.decks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("登録されている単語帳がありません。\n上のボタンから新規作成してください。")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(engine.decks) { deck in
                            HStack(spacing: 16) {
                                // Folder Icon
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(brownPanel)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deck.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(textDark)
                                    
                                    Text("\(deck.vocabList.count)語 登録")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Delete Deck Button
                                Button(action: {
                                    engine.deleteDeck(id: deck.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(incorrectRed)
                                }
                                .buttonStyle(BorderlessButtonStyle()) // Prevent click propagation in SwiftUI scroll view list
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .padding(16)
                            .background(creamCard)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCol, lineWidth: 1))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                engine.selectedDeckId = deck.id
                                visibleWordCount = 50
                                currentScreen = .setup
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(creamBg)
        }
        .alert("新しい単語帳を作成", isPresented: $showCreateDeckAlert) {
            TextField("単語帳の名前", text: $newDeckName)
            Button("キャンセル", role: .cancel) { newDeckName = "" }
            Button("作成") {
                engine.createDeck(name: newDeckName)
                newDeckName = ""
                currentScreen = .setup
            }
        } message: {
            Text("単語帳（フォルダー）の名前を入力してください。")
        }
    }
    
    // ==============================================
    // SCREEN 1: DECK SETTINGS & WORD EDITOR
    // ==============================================
    var setupScreen: some View {
        VStack(spacing: 0) {
            // Blue Header with Back button
            HStack(spacing: 12) {
                Button(action: {
                    currentScreen = .deckList
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                        Text("単語帳一覧")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(engine.selectedDeck?.name ?? "単語帳詳細")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Balance space
                Color.clear.frame(width: 80, height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(blueHeader)
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // CSV Import Card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("CSVファイルの追加読み込み", systemImage: "doc.badge.plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(textDark)
                        
                        Text("この単語帳の中にCSVデータの内容を追加インポートします。")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Button(action: { showFilePicker = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("CSVファイルを選択する")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(blueHeader)
                            .cornerRadius(12)
                            .shadow(color: blueHeader.opacity(0.2), radius: 5, y: 3)
                        }
                        
                        HStack {
                            Button(action: exportTemplateCSV) {
                                Text("ひな形CSVの保存")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(blueHeader)
                            }
                            Spacer()
                            Button(action: {
                                engine.resetSelectedDeckToDefault()
                            }) {
                                Text("デフォルトデータにする")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(incorrectRed)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(creamCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCol, lineWidth: 1))
                    
                    // Test Settings Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("テスト設定", systemImage: "gearshape")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(textDark)
                        
                        Picker("出題形式", selection: $engine.quizMode) {
                            Text("4択クイズ").tag(QuizMode.multipleChoice)
                            Text("単語帳").tag(QuizMode.flashcard)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical, 4)
                        
                        Divider()
                            .background(borderCol)
                        
                        // Range input
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("出題範囲")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(textDark)
                                Spacer()
                                Text("\((engine.selectedDeck?.vocabList.count) ?? 0)語ロード済み")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(blueHeader)
                                    .cornerRadius(10)
                            }
                            
                            Picker("出題範囲モード", selection: $engine.rangeMode) {
                                Text("番号で指定").tag(RangeMode.byNumber)
                                Text("ランダムに出題").tag(RangeMode.randomCount)
                                Text("苦手な単語のみ").tag(RangeMode.incorrectOnly)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 2)
                            
                            if engine.rangeMode == .byNumber {
                                HStack(spacing: 8) {
                                    TextField("1", value: $engine.rangeStart, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .focused($isInputFocused)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 60, height: 38)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderCol, lineWidth: 1))
                                    
                                    Text("番 から")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                    
                                    Text("〜")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    TextField("20", value: $engine.rangeEnd, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .focused($isInputFocused)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 60, height: 38)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderCol, lineWidth: 1))
                                    
                                    Text("番 まで")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                // Shortcuts
                                HStack(spacing: 6) {
                                    let total = (engine.selectedDeck?.vocabList.count) ?? 0
                                    Button("1-20") { engine.rangeStart = 1; engine.rangeEnd = min(20, total) }
                                        .buttonStyle(MiniButtonStyle())
                                    Button("21-40") { engine.rangeStart = min(21, total); engine.rangeEnd = min(40, total) }
                                        .buttonStyle(MiniButtonStyle())
                                    Button("全範囲") { engine.rangeStart = 1; engine.rangeEnd = total }
                                        .buttonStyle(MiniButtonStyle())
                                }
                                .padding(.top, 2)
                            } else if engine.rangeMode == .randomCount {
                                HStack(spacing: 8) {
                                    Text("全単語から")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                    
                                    TextField("20", value: $engine.randomQuestionCount, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .focused($isInputFocused)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 60, height: 38)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderCol, lineWidth: 1))
                                    
                                    Text("問を出題")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                // Shortcuts for random counts
                                HStack(spacing: 6) {
                                    let total = (engine.selectedDeck?.vocabList.count) ?? 0
                                    Button("10問") { engine.randomQuestionCount = 10 }
                                        .buttonStyle(MiniButtonStyle())
                                    Button("20問") { engine.randomQuestionCount = 20 }
                                        .buttonStyle(MiniButtonStyle())
                                    Button("50問") { engine.randomQuestionCount = 50 }
                                        .buttonStyle(MiniButtonStyle())
                                    Button("全問") { engine.randomQuestionCount = total }
                                        .buttonStyle(MiniButtonStyle())
                                }
                                .padding(.top, 2)
                            } else { // incorrectOnly
                                let totalFailed = engine.selectedDeck?.vocabList.filter { $0.incorrectCount > 0 }.count ?? 0
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(totalFailed > 0 ? incorrectRed : .gray)
                                        Text("過去に間違えたことのある単語を出題します")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    if totalFailed > 0 {
                                        Text("対象単語数: \(totalFailed) 語")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(textDark)
                                            .padding(.top, 2)
                                    } else {
                                        Text("※このフォルダには間違えた履歴のある単語がありません。")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(incorrectRed)
                                            .padding(.top, 2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        Divider()
                            .background(borderCol)
                            
                        // Setting switches
                        VStack(spacing: 12) {
                            Toggle(isOn: $engine.isShuffle) {
                                Text("シャッフル出題")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textDark)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: blueHeader))
                            
                            if engine.quizMode == .multipleChoice {
                                Toggle(isOn: $engine.isTimerEnabled) {
                                    Text("時間制限 (10秒)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(textDark)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: blueHeader))
                            }
                            
                            Toggle(isOn: $engine.isAudioEnabled) {
                                Text("効果音・音声再生")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textDark)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: blueHeader))
                        }
                    }
                    .padding(16)
                    .background(creamCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCol, lineWidth: 1))
                    
                    // Vocabulary Editor & Table Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("登録単語の編集 (\((engine.selectedDeck?.vocabList.count) ?? 0)語)", systemImage: "pencil.and.outline")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(textDark)
                            
                            Spacer()
                            
                            // Check weak words button
                            Button(action: {
                                isShowingWeakWordsSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("苦手確認")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(incorrectRed)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Add single word inline fields
                        VStack(alignment: .leading, spacing: 6) {
                            Text("単語の手動追加")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 6) {
                                TextField("単語 (例: run)", text: $newWord)
                                    .focused($isInputFocused)
                                    .font(.system(size: 12))
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderCol, lineWidth: 1))
                                
                                TextField("意味 (例: 走る)", text: $newMeaning)
                                    .focused($isInputFocused)
                                    .font(.system(size: 12))
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderCol, lineWidth: 1))
                                
                                Button(action: {
                                    engine.addWordToSelectedDeck(word: newWord, meaning: newMeaning)
                                    newWord = ""
                                    newMeaning = ""
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(correctGreen)
                                }
                                .disabled(newWord.isEmpty || newMeaning.isEmpty)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 8)
                        
                        Divider().background(borderCol)
                        
                        TextField("単語や意味で検索...", text: $searchText)
                            .font(.system(size: 12))
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderCol, lineWidth: 1))
                        
                        // Table list rows
                        VStack(spacing: 0) {
                            if let deck = engine.selectedDeck {
                                let filtered = deck.vocabList.enumerated().filter { (_, item) in
                                    searchText.isEmpty ||
                                    item.word.localizedCaseInsensitiveContains(searchText) ||
                                    item.meaning.localizedCaseInsensitiveContains(searchText)
                                }
                                
                                if filtered.isEmpty {
                                    Text("該当する単語がありません")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 20)
                                } else {
                                    ForEach(filtered.prefix(visibleWordCount), id: \.element.id) { index, item in
                                        HStack(spacing: 0) {
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.gray)
                                                .frame(width: 30, alignment: .leading)
                                            
                                            Text(item.word)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(textDark)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Text(item.meaning)
                                                .font(.system(size: 12))
                                                .foregroundColor(textDark)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            // Delete Word Button
                                            Button(action: {
                                                engine.deleteWordFromSelectedDeck(itemId: item.id)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(incorrectRed)
                                                    .padding(.horizontal, 8)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            engine.speak(text: item.word)
                                        }
                                        
                                        Divider()
                                            .background(borderCol.opacity(0.5))
                                    }
                                    
                                    if filtered.count > visibleWordCount {
                                        Button(action: {
                                            visibleWordCount += 50
                                        }) {
                                            HStack {
                                                Text("さらに表示 (\(filtered.count - visibleWordCount)件の未表示)")
                                                Image(systemName: "chevron.down")
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(blueHeader)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderCol, lineWidth: 1))
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(creamCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCol, lineWidth: 1))
                }
                .padding(16)
                .padding(.bottom, 80)
            }
            .background(creamBg)
            .simultaneousGesture(TapGesture().onEnded {
                isInputFocused = false
            })
            
            // Bottom Bar Button
            let isStartDisabled = engine.rangeMode == .incorrectOnly && (engine.selectedDeck?.vocabList.filter { $0.incorrectCount > 0 }.isEmpty ?? true)
            Button(action: {
                engine.startQuiz()
                currentScreen = .quiz
            }) {
                HStack {
                    Text("テスト開始")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isStartDisabled ? Color.gray : blueHeader)
                .cornerRadius(25)
                .shadow(color: isStartDisabled ? Color.clear : blueHeader.opacity(0.3), radius: 5, y: 3)
            }
            .disabled(isStartDisabled)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(creamBg.opacity(0.95))
            .overlay(
                VStack {
                    Divider().background(borderCol)
                    Spacer()
                }
            )
        }
        .edgesIgnoringSafeArea(.bottom)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let fileURL = try result.get().first else { return }
                
                // Start accessing security-scoped resource
                if fileURL.startAccessingSecurityScopedResource() {
                    defer { fileURL.stopAccessingSecurityScopedResource() }
                    
                    let data = try Data(contentsOf: fileURL)
                    if let text = String(data: data, encoding: .utf8) {
                        let success = engine.importCSVIntoSelectedDeck(text: text)
                        importAlertMsg = success ? "CSVファイルを単語帳に追加しました。" : "解析エラーが発生しました。ファイルのフォーマットを確認してください。"
                    } else {
                        importAlertMsg = "テキストファイルとして読み込めませんでした。エンコーディングはUTF-8で保存してください。"
                    }
                } else {
                    importAlertMsg = "ファイルへのアクセス権限がありません。"
                }
            } catch {
                importAlertMsg = "ファイルの読み込み中にエラーが発生しました: \(error.localizedDescription)"
            }
            showImportAlert = true
        }
        .alert("CSVインポート結果", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importAlertMsg)
        }
        .sheet(isPresented: $isShowingWeakWordsSheet) {
            WeakWordsSheet(engine: engine, isPresented: $isShowingWeakWordsSheet)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    isInputFocused = false
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(blueHeader)
            }
        }
    }
    
    // ==============================================
    // SCREEN 2: QUIZ INTERFACE (CONCEPT 1 WARM MINIMALIST)
    // ==============================================
    var quizScreen: some View {
        VStack(spacing: 0) {
            // Navigation Bar (integrated with background)
            HStack {
                Button(action: {
                    engine.stopQuiz()
                    currentScreen = .setup
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textDark.opacity(0.6))
                }
                .frame(width: 44, alignment: .leading)
                
                Spacer()
                
                let currentQuestion = min(engine.currentQuestionIndex + 1, engine.activeQuizList.count)
                Text("\(currentQuestion) of \(engine.activeQuizList.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(textDark.opacity(0.6))
                
                Spacer()
                
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)
            .padding(.bottom, 8)
            .background(creamBg)
            
            // Progress line (Delicate timer line)
            if engine.isTimerEnabled && engine.quizMode == .multipleChoice {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(borderCol.opacity(0.4))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(brownPanel) // Elegant brown gold
                            .frame(width: geo.size.width * CGFloat(engine.timeLeft), height: 3)
                            .animation(.linear(duration: 0.05), value: engine.timeLeft)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(creamBg)
            }
            
            // Question display area (Floating Rounded Card with shadow)
            VStack {
                if !engine.activeQuizList.isEmpty && engine.currentQuestionIndex < engine.activeQuizList.count {
                    let item = engine.activeQuizList[engine.currentQuestionIndex]
                    
                    if engine.quizMode == .multipleChoice {
                        Text(item.word)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(textDark)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 36)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(24)
                            .shadow(color: textDark.opacity(0.04), radius: 12, x: 0, y: 6)
                            .id(engine.currentQuestionIndex)
                    } else {
                        // Flashcard mode card (with tap action & flip animation)
                        VStack {
                            Text(isFlipped ? item.meaning : item.word)
                                .font(.system(size: isFlipped ? 26 : 36, weight: .bold))
                                .foregroundColor(textDark)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity)
                                // Prevent flipped text backward display
                                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: textDark.opacity(0.04), radius: 12, x: 0, y: 6)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isFlipped.toggle()
                            }
                        }
                        .id(engine.currentQuestionIndex)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(creamBg)
            
            // Option Buttons Area (Cream Background)
            VStack {
                if engine.quizMode == .multipleChoice {
                    VStack(spacing: 12) {
                        ForEach(engine.currentOptions) { option in
                            Button(action: {
                                engine.selectOption(optionId: option.id)
                            }) {
                                ZStack {
                                    Text(option.text)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(getOptionTextColor(option: option))
                                        .padding(.vertical, 18)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity)
                                        .background(getOptionBgColor(option: option))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(getOptionBorderColor(option: option), lineWidth: 1.5)
                                        )
                                        .scaleEffect(option.status == .correct ? 1.015 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: option.status)
                                    
                                    // Correct or incorrect badge symbols
                                    if option.status == .correct {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(Color(red: 0.15, green: 0.54, blue: 0.28))
                                                .padding(.trailing, 16)
                                        }
                                    } else if option.status == .incorrect {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "xmark")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(Color(red: 0.77, green: 0.12, blue: 0.15))
                                                .padding(.trailing, 16)
                                        }
                                    }
                                }
                            }
                            .disabled(hasUserAnswered())
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // "わからない" (skip) Button
                    Button(action: {
                        engine.selectDontKnow()
                    }) {
                        Text("わからない")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textDark.opacity(0.6))
                            .padding(.horizontal, 48)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(borderCol, lineWidth: 1))
                    }
                    .disabled(hasUserAnswered())
                    .padding(.bottom, 40)
                } else {
                    // Flashcard mode assessment buttons (Remembered vs Forgot)
                    Spacer()
                    
                    if isFlipped {
                        HStack(spacing: 20) {
                            // 覚えていない
                            Button(action: {
                                withAnimation {
                                    isFlipped = false
                                }
                                engine.resolveFlashcardAnswer(isCorrect: false)
                            }) {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("覚えていない")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(incorrectRed)
                                .cornerRadius(16)
                                .shadow(color: incorrectRed.opacity(0.3), radius: 5, y: 3)
                            }
                            
                            // 覚えている
                            Button(action: {
                                withAnimation {
                                    isFlipped = false
                                }
                                engine.resolveFlashcardAnswer(isCorrect: true)
                            }) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("覚えている")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(correctGreen)
                                .cornerRadius(16)
                                .shadow(color: correctGreen.opacity(0.3), radius: 5, y: 3)
                            }
                        }
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Hint text
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 24))
                                .foregroundColor(textDark.opacity(0.3))
                            Text("タップして意味を表示")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(textDark.opacity(0.4))
                        }
                        .padding(.vertical, 30)
                        .transition(.opacity)
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(creamBg)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if engine.quizMode == .flashcard && !isFlipped {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isFlipped = true
                }
            }
        }
        .onChange(of: engine.currentQuestionIndex) { val in
            isFlipped = false
            if val >= engine.activeQuizList.count && !engine.activeQuizList.isEmpty {
                currentScreen = .results
            }
        }
    }
    
    // ==============================================
    // SCREEN 3: RESULTS SCREEN
    // ==============================================
    var resultsScreen: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 2) {
                Text("テスト結果")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(textDark)
                if engine.rangeMode == .byNumber {
                    Text("出題範囲: No. \(engine.rangeStart) 〜 \(engine.rangeEnd)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                } else if engine.rangeMode == .randomCount {
                    Text("出題範囲: ランダム \(engine.activeQuizList.count)問")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    Text("出題範囲: 苦手単語のみ \(engine.activeQuizList.count)問")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Circular Progress & Stats
                    VStack(spacing: 20) {
                        let pct = getAccuracyPercent()
                        
                        ZStack {
                            Circle()
                                .stroke(borderCol, lineWidth: 8)
                                .frame(width: 130, height: 130)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(pct) / 100.0)
                                .stroke(blueHeader, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 130, height: 130)
                                .rotationEffect(Angle(degrees: -90))
                            
                            VStack(spacing: 2) {
                                Text("\(pct)%")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(textDark)
                                Text("\(engine.score) / \(engine.activeQuizList.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 10)
                        
                        Divider().background(borderCol)
                        
                        // Three Columns Stats
                        HStack {
                            VStack {
                                Text("\(engine.score)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(textDark)
                                Text("正解")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 30)
                            
                            VStack {
                                Text("\(engine.activeQuizList.count - engine.score)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(incorrectRed)
                                Text("誤答・未解答")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 30)
                            
                            VStack {
                                Text(String(format: "%.1fs", getAverageTime()))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(textDark)
                                Text("平均時間")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                    .background(creamCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCol, lineWidth: 1))
                    
                    // Review List Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今回の出題リスト")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(textDark)
                        Text("タップすると英単語の音声が再生されます。")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(.bottom, 6)
                        
                        Divider().background(borderCol)
                        
                        // Scrollable rows
                        ForEach(engine.quizAnswers) { answer in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(answer.isCorrect ? correctGreen : incorrectRed)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Image(systemName: answer.isCorrect ? "checkmark" : "xmark")
                                            .font(.system(size: 8, weight: .heavy))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(answer.word)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(textDark)
                                    
                                    HStack(spacing: 4) {
                                        Text(answer.meaning)
                                        if !answer.isCorrect {
                                            Text("(あなたの解答: \(answer.chosen))")
                                                .foregroundColor(incorrectRed)
                                        }
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                engine.speak(text: answer.word)
                            }
                            
                            Divider().background(borderCol.opacity(0.5))
                        }
                    }
                    .padding(16)
                    .background(creamCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCol, lineWidth: 1))
                }
                .padding(16)
                .padding(.bottom, 150)
            }
            .background(creamBg)
            
            // Bottom Action buttons
            VStack(spacing: 8) {
                let hasIncorrect = engine.quizAnswers.contains(where: { !$0.isCorrect })
                
                if hasIncorrect {
                    Button(action: {
                        engine.retryIncorrectOnly()
                        currentScreen = .quiz
                    }) {
                        Text("誤答のみ再テスト")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(textDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white)
                            .cornerRadius(22)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(borderCol, lineWidth: 1))
                    }
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        engine.startQuiz()
                        currentScreen = .quiz
                    }) {
                        Text("もう一度挑戦")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(textDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(borderCol, lineWidth: 1))
                    }
                    
                    Button(action: {
                        currentScreen = .setup
                    }) {
                        Text("設定に戻る")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(blueHeader)
                            .cornerRadius(24)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(creamBg.opacity(0.95))
            .overlay(
                VStack {
                    Divider().background(borderCol)
                    Spacer()
                }
            )
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // ==============================================
    // UI DISPLAY HELPERS
    // ==============================================
    
    private func hasUserAnswered() -> Bool {
        return engine.currentOptions.contains(where: { $0.status != .normal })
    }
    
    private func getOptionTextColor(option: QuizEngine.Option) -> Color {
        switch option.status {
        case .normal: return textDark
        case .correct: return Color(red: 0.15, green: 0.54, blue: 0.28) // Dark green text
        case .incorrect: return Color(red: 0.77, green: 0.12, blue: 0.15) // Dark red text
        case .faded: return textDark.opacity(0.2)
        }
    }
    
    private func getOptionBgColor(option: QuizEngine.Option) -> Color {
        switch option.status {
        case .normal: return .white
        case .correct: return Color(red: 0.91, green: 0.97, blue: 0.93) // Soft green background
        case .incorrect: return Color(red: 0.99, green: 0.92, blue: 0.92) // Soft red background
        case .faded: return .white.opacity(0.5)
        }
    }
    
    private func getOptionBorderColor(option: QuizEngine.Option) -> Color {
        switch option.status {
        case .normal: return borderCol
        case .correct: return correctGreen.opacity(0.6)
        case .incorrect: return incorrectRed.opacity(0.6)
        case .faded: return borderCol.opacity(0.5)
        }
    }
    
    private func getAccuracyPercent() -> Int {
        guard !engine.activeQuizList.isEmpty else { return 0 }
        return Int(Double(engine.score) / Double(engine.activeQuizList.count) * 100.0)
    }
    
    private func getAverageTime() -> Double {
        guard !engine.quizAnswers.isEmpty else { return 0 }
        let total = engine.quizAnswers.reduce(0.0) { $0 + $1.timeSpent }
        return total / Double(engine.quizAnswers.count)
    }
    
    private func exportTemplateCSV() {
        let csvText = engine.getTemplateCSVContent()
        #if os(iOS)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("custom_vocab_template.csv")
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                // For iPads
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to save template CSV: \(error)")
        }
        #endif
    }
}

// Mini Button Style for shortcuts
struct MiniButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color(red: 0.173, green: 0.122, blue: 0.082))
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.898, green: 0.878, blue: 0.835), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct WeakWordsSheet: View {
    @ObservedObject var engine: QuizEngine
    @Binding var isPresented: Bool
    
    // Color Palette matching Reference
    let creamBg = Color(red: 0.976, green: 0.96, blue: 0.92)       // #F9F5EB
    let creamCard = Color(red: 0.98, green: 0.965, blue: 0.933)    // #FAF6EE
    let borderCol = Color(red: 0.898, green: 0.878, blue: 0.835)   // #E5E0D5
    let textDark = Color(red: 0.173, green: 0.122, blue: 0.082)    // #2C1F15
    let correctGreen = Color(red: 0.3, green: 0.85, blue: 0.39)    // #4CD964
    let incorrectRed = Color(red: 1.0, green: 0.23, blue: 0.188)   // #FF3B30

    var body: some View {
        NavigationView {
            ZStack {
                creamBg.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    if let deck = engine.selectedDeck {
                        // Filter words that have been mistaken at least once
                        let weakWords = deck.vocabList
                            .filter { $0.incorrectCount > 0 }
                            .sorted { $0.incorrectCount > $1.incorrectCount }
                        
                        if weakWords.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(correctGreen)
                                Text("間違えた単語はありません！")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(textDark)
                                Text("クイズや単語帳モードで間違えた単語が\nここにミス回数の多い順で表示されます。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(weakWords) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.word)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(textDark)
                                            Text(item.meaning)
                                                .font(.system(size: 13))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(item.incorrectCount)回ミス")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(incorrectRed)
                                            .cornerRadius(6)
                                        
                                        // Reset individual count
                                        Button(action: {
                                            engine.resetIncorrectCount(for: item.id)
                                        }) {
                                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.gray.opacity(0.6))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.leading, 8)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(creamCard)
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
            }
            .navigationTitle("苦手単語（間違えた履歴）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let deck = engine.selectedDeck, deck.vocabList.contains(where: { $0.incorrectCount > 0 }) {
                        Button("すべてリセット") {
                            engine.resetAllIncorrectCountsInSelectedDeck()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(incorrectRed)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        isPresented = false
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(textDark)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
