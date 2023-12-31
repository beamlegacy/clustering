/// Text extraction based on JusText https://github.com/miso-belica/jusText/blob/main/doc/algorithm.rst
/// and the PhD dissertation https://is.muni.cz/th/45523/fi_d/phdthesis.pdf
/// Stropwords taken from https://www.ranks.nl/stopwords

import Foundation
import NaturalLanguage

class JusText {
    enum Rates {
        case low
        case medium
        case high
        case undefined
    }

    enum BlockClasses {
        case bad
        case good
        case nearGood
        case short
    }

    enum BlockClassesError: Error {
        case sizeMismatch
        case blockLengthUndefined
    }

    let lengthLow = 70 // in characters
    let lengthHigh = 200 // in characters
    let stopwordsLow: [NLLanguage: Double] = [NLLanguage.english: 0.3, NLLanguage.french: 0.24, NLLanguage.dutch: 0.23]
    let stopwordsHigh: [NLLanguage: Double] = [NLLanguage.english: 0.33, NLLanguage.french: 0.27, NLLanguage.dutch: 0.26]
    let stopwordsLowBaseline = 0.3 // percentage
    let stopwordsHighBaseline = 0.33  // percentage

    let stopWords: [NLLanguage: [String]] = [
        NLLanguage.english: ["a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any", "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below", "between", "both", "but", "by", "can't", "cannot", "could", "couldn't", "did", "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during", "each", "few", "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't", "having", "he", "he'd", "he'll", "he's", "her", "here", "here's", "hers", "herself", "him", "himself", "his", "how", "how's", "i", "i'd", "i'll", "i'm", "i've", "if", "in", "into", "is", "isn't", "it", "it's", "its", "itself", "let's", "me", "more", "most", "mustn't", "my", "myself", "no", "nor", "not", "of", "off", "on", "once", "only", "or", "other", "ought", "our", "oursourselves", "out", "over", "own", "same", "shan't", "she", "she'd", "she'll", "she's", "should", "shouldn't", "so", "some", "such", "than", "that", "that's", "the", "their", "theirs", "them", "themselves", "then", "there", "there's", "these", "they", "they'd", "they'll", "they're", "they've", "this", "those", "through", "to", "too", "under", "until", "up", "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were", "weren't", "what", "what's", "when", "when's", "where", "where's", "which", "while", "who", "who's", "whom", "why", "why's", "with", "won't", "would", "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours", "yourself", "yourselves"],
        NLLanguage.french: ["alors", "au", "aucuns", "aussi", "autre", "avant", "avec", "avoir", "bon", "car", "ce", "cela", "ces", "ceux", "chaque", "ci", "comme", "comment", "dans", "des", "du", "dedans", "dehors", "depuis", "devrait", "doit", "donc", "dos", "début", "elle", "elles", "en", "encore", "essai", "est", "et", "eu", "fait", "faites", "fois", "font", "hors", "ici", "il", "ils", "je", "juste", "la", "le", "les", "leur", "là", "ma", "maintenant", "mais", "mes", "mien", "moins", "mon", "mot", "même", "ni", "nommés", "notre", "nous", "ou", "où", "par", "parce", "pas", "peut", "peu", "plupart", "pour", "pourquoi", "quand", "que", "quel", "quelle", "quelles", "quels", "qui", "sa", "sans", "ses", "seulement", "si", "sien", "son", "sont", "sous", "soyez", "sujet", "sur", "ta", "tandis", "tellement", "tels", "tes", "ton", "tous", "tout", "trop", "très", "tu", "voient", "vont", "votre", "vous", "vu", "ça", "étaient", "état", "étions", "été", "être"],
        NLLanguage.german: ["aber", "als", "am", "an", "auch", "auf", "aus", "bei", "bin", "bis", "bist", "da", "dadurch", "daher", "darum", "das", "da&szlig;", "dass", "dein", "deine", "dem", "den", "der", "des", "dessen", "deshalb", "die", "dies", "dieser", "dieses", "doch", "dort", "du", "durch", "ein", "eine", "einem", "einen", "einer", "eines", "er", "es", "euer", "eure", "für", "hatte", "hatten", "hattest", "hattet", "hier", "hinter", "ich", "ihr", "ihre", "im", "in", "ist", "ja", "jede", "jedem", "jeden", "jeder", "jedes", "jener", "jenes", "jetzt", "kann", "kannst", "können", "könnt", "machen", "mein", "meine", "mit", "muß", "mußt", "musst", "müssen", "müßt", "nach", "nachdem", "nein", "nicht", "nun", "oder", "seid", "sein", "seine", "sich", "sie", "sind", "soll", "sollen", "sollst", "sollt", "sonst", "soweit", "sowie", "und", "unser", "unsere", "unter", "vom", "von", "vor", "wann", "warum", "was", "weiter", "weitere", "wenn", "wer", "werde", "werden", "werdet", "weshalb", "wie", "wieder", "wieso", "wir", "wird", "wirst", "wo", "woher", "wohin", "zu", "zum", "zur", "über"],
        NLLanguage.italian: ["a", "adesso", "ai", "al", "alla", "allo", "allora", "altre", "altri", "altro", "anche", "ancora", "avere", "aveva", "avevano", "ben", "buono", "che", "chi", "cinque", "comprare", "con", "consecutivi", "consecutivo", "cosa", "cui", "da", "del", "della", "dello", "dentro", "deve", "devo", "di", "doppio", "due", "e", "ecco", "fare", "fine", "fino", "fra", "gente", "giu", "ha", "hai", "hanno", "ho", "il", "indietro", "invece", "io", "la", "lavoro", "le", "lei", "lo", "loro", "lui", "lungo", "ma", "me", "meglio", "molta", "molti", "molto", "nei", "nella", "no", "noi", "nome", "nostro", "nove", "nuovi", "nuovo", "o", "oltre", "ora", "otto", "peggio", "pero", "persone", "piu", "poco", "primo", "promesso", "qua", "quarto", "quasi", "quattro", "quello", "questo", "qui", "quindi", "quinto", "rispetto", "sara", "secondo", "sei", "sembra", "sembrava", "senza", "sette", "sia", "siamo", "siete", "solo", "sono", "sopra", "soprattutto", "sotto", "stati", "stato", "stesso", "su", "subito", "sul", "sulla", "tanto", "te", "tempo", "terzo", "tra", "tre", "triplo", "ultimo", "un", "una", "uno", "va", "vai", "voi", "volte", "vostro"],
        NLLanguage.russian: ["а", "е", "и", "ж", "м", "о", "на", "не", "ни", "об", "но", "он", "мне", "мои", "мож", "она", "они", "оно", "мной", "много", "многочисленное", "многочисленная", "многочисленные", "многочисленный", "мною", "мой", "мог", "могут", "можно", "может", "можхо", "мор", "моя", "моё", "мочь", "над", "нее", "оба", "нам", "нем", "нами", "ними", "мимо", "немного", "одной", "одного", "менее", "однажды", "однако", "меня", "нему", "меньше", "ней", "наверху", "него", "ниже", "мало", "надо", "один", "одиннадцать", "одиннадцатый", "назад", "наиболее", "недавно", "миллионов", "недалеко", "между", "низко", "меля", "нельзя", "нибудь", "непрерывно", "наконец", "никогда", "никуда", "нас", "наш", "нет", "нею", "неё", "них", "мира", "наша", "наше", "наши", "ничего", "начала", "нередко", "несколько", "обычно", "опять", "около", "мы", "ну", "нх", "от", "отовсюду", "особенно", "нужно", "очень", "отсюда", "в", "во", "вон", "вниз", "внизу", "вокруг", "вот", "восемнадцать", "восемнадцатый", "восемь", "восьмой", "вверх", "вам", "вами", "важное", "важная", "важные", "важный", "вдали", "везде", "ведь", "вас", "ваш", "ваша", "ваше", "ваши", "впрочем", "весь", "вдруг", "вы", "все", "второй", "всем", "всеми", "времени", "время", "всему", "всего", "всегда", "всех", "всею", "всю", "вся", "всё", "всюду", "г", "год", "говорил", "говорит", "года", "году", "где", "да", "ее", "за", "из", "ли", "же", "им", "до", "по", "ими", "под", "иногда", "довольно", "именно", "долго", "позже", "более", "должно", "пожалуйста", "значит", "иметь", "больше", "пока", "ему", "имя", "пор", "пора", "потом", "потому", "после", "почему", "почти", "посреди", "ей", "два", "две", "двенадцать", "двенадцатый", "двадцать", "двадцатый", "двух", "его", "дел", "или", "без", "день", "занят", "занята", "занято", "заняты", "действительно", "давно", "девятнадцать", "девятнадцатый", "девять", "девятый", "даже", "алло", "жизнь", "далеко", "близко", "здесь", "дальше", "для", "лет", "зато", "даром", "первый", "перед", "затем", "зачем", "лишь", "десять", "десятый", "ею", "её", "их", "бы", "еще", "при", "был", "про", "процентов", "против", "просто", "бывает", "бывь", "если", "люди", "была", "были", "было", "будем", "будет", "будете", "будешь", "прекрасно", "буду", "будь", "будто", "будут", "ещё", "пятнадцать", "пятнадцатый", "друго", "другое", "другой", "другие", "другая", "других", "есть", "пять", "быть", "лучше", "пятый", "к", "ком", "конечно", "кому", "кого", "когда", "которой", "которого", "которая", "которые", "который", "которых", "кем", "каждое", "каждая", "каждые", "каждый", "кажется", "как", "какой", "какая", "кто", "кроме", "куда", "кругом", "с", "т", "у", "я", "та", "те", "уж", "со", "то", "том", "снова", "тому", "совсем", "того", "тогда", "тоже", "собой", "тобой", "собою", "тобою", "сначала", "только", "уметь", "тот", "тою", "хорошо", "хотеть", "хочешь", "хоть", "хотя", "свое", "свои", "твой", "своей", "своего", "своих", "свою", "твоя", "твоё", "раз", "уже", "сам", "там", "тем", "чем", "сама", "сами", "теми", "само", "рано", "самом", "самому", "самой", "самого", "семнадцать", "семнадцатый", "самим", "самими", "самих", "саму", "семь", "чему", "раньше", "сейчас", "чего", "сегодня", "себе", "тебе", "сеаой", "человек", "разве", "теперь", "себя", "тебя", "седьмой", "спасибо", "слишком", "так", "такое", "такой", "такие", "также", "такая", "сих", "тех", "чаще", "четвертый", "через", "часто", "шестой", "шестнадцать", "шестнадцатый", "шесть", "четыре", "четырнадцать", "четырнадцатый", "сколько", "сказал", "сказала", "сказать", "ту", "ты", "три", "эта", "эти", "что", "это", "чтоб", "этом", "этому", "этой", "этого", "чтобы", "этот", "стал", "туда", "этим", "этими", "рядом", "тринадцать", "тринадцатый", "этих", "третий", "тут", "эту", "суть", "чуть", "тысяч"],
        NLLanguage.spanish: ["un", "una", "unas", "unos", "uno", "sobre", "todo", "tambi&eacute;n", "tras", "otro", "alg&uacute;n", "alguno", "alguna", "algunos", "algunas", "ser", "es", "soy", "eres", "somos", "sois", "estoy", "esta", "estamos", "estais", "estan", "como", "en", "para", "atras", "porque", "por qu&eacute;", "estado", "estaba", "ante", "antes", "siendo", "ambos", "pero", "por", "poder", "puede", "puedo", "podemos", "podeis", "pueden", "fui", "fue", "fuimos", "fueron", "hacer", "hago", "hace", "hacemos", "haceis", "hacen", "cada", "fin", "incluso", "primero", "desde", "conseguir", "consigo", "consigue", "consigues", "conseguimos", "consiguen", "ir", "voy", "va", "vamos", "vais", "van", "vaya", "gueno", "ha", "tener", "tengo", "tiene", "tenemos", "teneis", "tienen", "el", "la", "lo", "las", "los", "su", "aqui", "mio", "tuyo", "ellos", "ellas", "nos", "nosotros", "vosotros", "vosotras", "si", "dentro", "solo", "solamente", "saber", "sabes", "sabe", "sabemos", "sabeis", "saben", "ultimo", "largo", "bastante", "haces", "muchos", "aquellos", "aquellas", "sus", "entonces", "tiempo", "verdad", "verdadero", "verdadera", "cierto", "ciertos", "cierta", "ciertas", "intentar", "intento", "intenta", "intentas", "intentamos", "intentais", "intentan", "dos", "bajo", "arriba", "encima", "usar", "uso", "usas", "usa", "usamos", "usais", "usan", "emplear", "empleo", "empleas", "emplean", "ampleamos", "empleais", "valor", "muy", "era", "eras", "eramos", "eran", "modo", "bien", "cual", "cuando", "donde", "mientras", "quien", "con", "entre", "sin", "trabajo", "trabajar", "trabajas", "trabaja", "trabajamos", "trabajais", "trabajan", "podria", "podrias", "podriamos", "podrian", "podriais", "yo", "aquel"],
        NLLanguage.dutch: ["aan", "af", "al", "als", "bij", "dan", "dat", "die", "dit", "een", "en", "er", "had", "heb", "hem", "het", "hij", "hoe", "hun", "ik","in", "is", "je", "kan", "me", "men", "met", "mij", "nog", "nu", "of", "ons", "ook", "te", "tot", "uit", "van", "was", "wat", "we", "wel", "wij", "zal", "ze", "zei", "zij", "zo", "zou"]
    ]

    public init() {
    }

    /// Detect the dominant language of a given text..
    ///
    /// - Parameters:
    ///   - text: The text from which the dominant language is detected
    /// - Returns: The dominant language.
    func getTextLanguage(text: String) -> NLLanguage? {
        let languageToReturn = NLLanguageRecognizer.dominantLanguage(for: text)
        return languageToReturn
    }

    /// Rate the length of each block in the text (low, medium, high)
    ///
    /// - Parameters:
    ///   - blocks: Blocks of text extracted from HTML
    /// - Returns: A rate of the length of each block
    func rateLength(of blocks: [String]) -> [Rates] {
        return blocks.map { block in
            if block.count < lengthLow {
                return Rates.low
            } else if block.count < lengthHigh {
                return Rates.medium
            } else {
                return Rates.high
            }
        }
    }

    /// Rate the stopword density of each block in the text (low, medium, high)
    ///
    /// - Parameters:
    ///   - blocks: Blocks of text extracted from HTML
    /// - Returns: A rate of the length of each block
    func rateStopwordDensity(of blocks: [String], with languages: [NLLanguage?]) -> [Rates] {
        return zip(blocks, languages).map { (block, language) in
            if let language = language,
               let stopWordsInLanguage = self.stopWords[language] {
                let splitted = Array(block.trimmingCharacters(in: .punctuationCharacters).split(separator: " "))
                let totalWords = Double(splitted.count)
                let numStopWords = Double(splitted.filter({ stopWordsInLanguage.contains(String($0.lowercased())) }).count)
                switch numStopWords / totalWords {
                case  0..<(self.stopwordsLow[language] ?? self.stopwordsLowBaseline):
                    return Rates.low
                case (self.stopwordsLow[language] ?? self.stopwordsLowBaseline)..<(self.stopwordsHigh[language] ?? self.stopwordsHighBaseline):
                    return Rates.medium
                default:
                    return Rates.high
                }
            } else {
                return Rates.undefined
            }
        }
    }

    /// Classify the quality of each block of text individually (good, bad, near-good or short).
    ///
    /// - Parameters:
    ///   - blockLengths: A rate of the length of each block
    ///   - blockStopWords: A rate of the stopword density for each blcok of text (optional, depending on the language)
    /// - Returns: A classification for each block of text
    func determinePerBlock(blockLengths: [Rates], blockStopWords: [Rates]) throws -> [BlockClasses] {
        // Make sure that both sets of rates are of the same size
        guard blockLengths.count == blockStopWords.count else {
            throw BlockClassesError.sizeMismatch
        }
        var blockClasses: [BlockClasses] = []
        for (blockLength, blockStopWords) in zip(blockLengths, blockStopWords) {
            if blockStopWords == .undefined {
                switch blockLength {
                case .low:
                    blockClasses.append(.bad)
                case .medium:
                    blockClasses.append(.nearGood)
                case .high:
                    blockClasses.append(.good)
                default:
                    throw BlockClassesError.blockLengthUndefined
                    
                }
            } else if blockLength == .low {
                blockClasses.append(.short)
            } else {
                switch blockStopWords {
                case .low:
                    blockClasses.append(.bad)
                case .medium:
                    blockClasses.append(.nearGood)
                case .high:
                    if blockLength == .medium {
                        blockClasses.append(.nearGood)
                    } else {
                        blockClasses.append(.good)
                    }
                default:
                    blockClasses.append(.bad) // This cannot happen since we're inside an else about blockStopWords
                }
            }
        }
        return blockClasses
    }

    /// Evolve the classification of each block of text by considering its environment
    ///
    /// - Parameters:
    ///   - blockClasses: A classification for each block of text (good, bad, near-good or short)
    /// - Returns: A new classification for each block of text (good or bad only)
    func determineAllBlocks(blockClasses: [BlockClasses]) -> [BlockClasses] {
        var finalBlockClasses: [BlockClasses] = []
        var beforeDelimiter: BlockClasses = .bad
        for block in blockClasses.enumerated() {
            if block.element == .good || block.element == .bad {
                finalBlockClasses.append(block.element)
                beforeDelimiter = block.element
                continue
            }
            let nextGood = blockClasses[block.offset..<blockClasses.count].firstIndex(of: .good)
            let nextBad = blockClasses[block.offset..<blockClasses.count].firstIndex(of: .bad)
            let afterDelimiter = (nextGood ?? blockClasses.count) < (nextBad ?? blockClasses.count) ? BlockClasses.good : BlockClasses.bad
            if beforeDelimiter == afterDelimiter {
                finalBlockClasses.append(beforeDelimiter)
                continue
            }
            if beforeDelimiter == .bad {
                if blockClasses[0...block.offset].lastIndex(of: .nearGood) ?? 0 > blockClasses[0..<block.offset].lastIndex(of: .bad) ?? 0 {
                    finalBlockClasses.append(.good)
                } else {
                    finalBlockClasses.append(.bad)
                }
            } else {
                if blockClasses[block.offset..<blockClasses.count].firstIndex(of: .nearGood) ?? blockClasses.count < blockClasses[block.offset+1..<blockClasses.count].firstIndex(of: .bad) ?? blockClasses.count {
                    finalBlockClasses.append(.good)
                } else {
                    finalBlockClasses.append(.bad)
                }
            }
        }
        return finalBlockClasses
    }

    /// Extract a string to represent a page out of the block extracted from its HTML
    ///
    /// - Parameters:
    ///   - blocks: Blocks of text extracted from HTML
    /// - Returns: A string to represent the page (can be empty) and the language of the page (if detected)
    public func extract(from blocks: [String], forType dataPoint: LegacyClustering.DataPoint = .page) throws -> (String, NLLanguage?) {
        let languageEachBlock = blocks.map({ self.getTextLanguage(text: $0) })
        let lengths = self.rateLength(of: blocks)
        let stopwords = self.rateStopwordDensity(of: blocks, with: languageEachBlock)
        let temporaryRates = try self.determinePerBlock(blockLengths: lengths, blockStopWords: stopwords)
//        let finalRates = self.determineAllBlocks(blockClasses: temporaryRates)
//        guard finalRates.count == blocks.count else {
//            throw BlockClassesError.sizeMismatch
//        }

        // Check if there's a "good" rating with a known language
        let blocksWithGoodRating = Set(temporaryRates.enumerated().map { rate -> Int in
            if rate.element == .good {
                return rate.offset
            } else {
                return temporaryRates.count
            }
        }).filter { $0 != temporaryRates.count }
        let blocksWithLangauge = Set(languageEachBlock.enumerated().map { language -> Int in
            if let languageElement = language.element,
               self.stopWords.keys.contains(languageElement) {
                return language.offset
            } else {
                return languageEachBlock.count
            }
        }).filter { $0 != languageEachBlock.count }
        var perfectBlocks = blocksWithLangauge.intersection(blocksWithGoodRating)
        if perfectBlocks.count == 0 {
           perfectBlocks = blocksWithGoodRating
        }
        let sortedIndeces = Array(perfectBlocks.sorted { $0 < $1 })
        var finalLanguage = NLLanguage.undetermined
        if sortedIndeces.count > 0,
           languageEachBlock.count > sortedIndeces[0] {
            finalLanguage = languageEachBlock[sortedIndeces[0]] ?? NLLanguage.undetermined
        }
        // TODO: Take care of the case where acceptable text appears in more than one language
        var finalString = ""
        for perfectBlockIndex in sortedIndeces {
            if languageEachBlock[perfectBlockIndex] == nil || languageEachBlock[perfectBlockIndex] == finalLanguage {
                finalString += " " + blocks[perfectBlockIndex]
            }
            if finalString.split(separator: " ").count > 512 && dataPoint == .page {
                break
            }
        }
        return (finalString.trimmingCharacters(in: .whitespacesAndNewlines), finalLanguage)
    }
}
