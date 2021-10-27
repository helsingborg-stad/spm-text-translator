import Foundation
import Combine

/// Used to identfy a language. Must comply with Locale.languageCode
public typealias LanguageKey = String
/// A translated value
public typealias TranslatedValue = String
/// The key poiunting to a translated value
public typealias TranslationKey = String

/// Errors occuring within TextTranslator
enum TextTranslatorError: Error {
    case missingService
}

/// Protocol used by values that can be translated
public protocol Translatable {
    /// Should map $0.stringsForTranslation and return a new array
    var stringsForTranslation: [String] { get }
}
/// Array default extension for an array of elements implementing the `Translatable` protocol
public extension Array where Element: Translatable {
    /// Maps $0.stringsForTranslation and returns a new array
    var stringsForTranslation: [String] {
        var arr = [String]()
        for s in self {
            arr.append(contentsOf: s.stringsForTranslation)
        }
        return arr
    }
}
/// Holds translated strings for x languages
public struct TextTranslationTable {
    /// The translation database
    public var db: [LanguageKey: [TranslationKey: TranslatedValue]] = [:]
    /// Initializes a new table
    public init() {
    }
    /// Merge self with another table. Any value that exists in the new table will overwrite the current database values
    /// - Parameter table: table to merge with
    public mutating func merge(with table:TextTranslationTable) {
        for (lang,vals) in table.db {
            for (k,v) in vals {
                if db[lang] == nil {
                    db[lang] = [:]
                }
                db[lang]?[k] = v
            }
        }
    }
    /// Remove all provided strings, in all languages, from database
    /// - Parameter strings: strings to remove
    public mutating func remove(strings:[String]) {
        var db = db
        for (lang,dict) in db {
            var dict = dict
            for s in strings {
                guard let index = dict.index(forKey: s) else {
                    continue
                }
                dict.remove(at: index)
            }
            if !dict.isEmpty {
                db[lang] = dict
            } else {
                db[lang] = nil
            }
        }
        self.db = db
    }
    /// Confirms or denies the existanse of a value for the provided key and language
    /// - Parameters:
    ///   - key: key for value
    ///   - language: language for translation
    /// - Returns: true if translated, false if not
    public func translationExists(forKey key: TranslationKey, in language: LanguageKey) -> Bool {
        return db[language]?[key] != nil
    }
    
    /// Add translation for key in language
    /// - Parameters:
    ///   - value: the value
    ///   - key: the key
    ///   - language: the language
    mutating public func set(value:TranslatedValue, for key:TranslationKey, in language:LanguageKey) {
        if db[language] == nil {
            db[language] = [:]
        }
        db[language]?[key] = value
    }
    
    /// Populate the table with a dictionary of keys and values in the specified language. Adds/replaces each value seperately without replacing the database dictionary for the specified language.
    /// - Parameters:
    ///   - dictionary: the dictionary
    ///   - language: the language
    mutating public func set(dictionary:[TranslationKey:TranslatedValue], in language:LanguageKey) {
        for (key,value) in dictionary {
            self.set(value: value, for: key, in: language)
        }
    }
    
    /// Finds which keys are missing translations
    /// - Parameters:
    ///   - keys: keys used to search
    ///   - languages: the languages in which to find a translation
    /// - Returns: dictionary containing a list of missing translation languages for each key
    public func findUntranslated(using keys:[TranslationKey], in languages: [LanguageKey]) -> [TranslationKey:[LanguageKey]] {
        var dict = [TranslationKey:[LanguageKey]]()
        for l in languages {
            for k in keys  {
                if !translationExists(forKey:k, in: l) {
                    if dict[k] == nil {
                        dict[k] = []
                    }
                    dict[k]?.append(l)
                }
            }
        }
        return dict
    }
    
    /// Returns the value for a given key and language
    /// - Parameters:
    ///   - forKey: the key
    ///   - language: the language
    /// - Returns: the translated value for given key in language
    public func value(forKey key: TranslationKey, in language:LanguageKey) -> TranslatedValue? {
        return db[language]?[key]
    }
    /// Checks if there is any untranslated values for a set of keys an languages
    /// - Parameters:
    ///   - keys: keys to check for
    ///   - languages: the set of languages to check for
    /// - Returns: true if there is any key that's missing a translation, false if not
    public func hasUntranslatedValues(for keys:[TranslationKey], in languages: [LanguageKey]) -> Bool {
        for l in languages {
            for k in keys  {
                if !translationExists(forKey: k, in: l) {
                    return true
                }
            }
        }
        return false
    }
    public var isEmpty:Bool {
        return db.isEmpty
    }
}
/// A translated string, used when calling TextTranslationService.translate(text:from:to:)
public struct TranslatedString {
    /// The language of the value
    public let language: LanguageKey
    /// Key, usually or always the original string
    public let key: TranslationKey
    /// The transalted value
    public let value: TranslatedValue
    
    /// Initializes a new instance
    /// - Parameters:
    ///   - language: The language of the value
    ///   - key: Key, usually or always the original string
    ///   - value: The transalted value
    public init(language: LanguageKey, key: TranslationKey, value: TranslatedValue) {
        self.language = language
        self.key = key
        self.value = value
    }
}

/// Publisher used when translating a single text
public typealias TranslatedPublisher = AnyPublisher<TranslatedString, Error>
/// Publisher used when translating mutiple texts
public typealias FinishedPublisher = AnyPublisher<TextTranslationTable, Error>
/// Subject used when translating a single text
public typealias TranslatedSubject = PassthroughSubject<TranslatedString, Error>
/// Subject used when translating multiple texts
public typealias FinishedSubject = PassthroughSubject<TextTranslationTable, Error>


/// Implemented by text translations services. The `TextTranslator` singleton does not keep a queue, if that kind of functionality is important the implemeted `TextTranslationService` would need to manage that on it's own.
public protocol TextTranslationService {
    /// Translate all texts in a dictionary from one language to one or more languages
    /// - Note: The service provider does not check if `to` contains `from`
    /// - Parameters:
    ///   - texts: dictionary to translate where the key can be anything and the string the text you wish to translate
    ///   - from: language if text in dictionary
    ///   - to: languages to translate into
    ///   - table: a table containing all translated (and original) texts
    /// - Returns: a completion publisher
    func translate(_ texts: [TranslationKey:String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTranslationTable) -> FinishedPublisher
    /// Translate all texts in an array from one language to one or more languages. The service is responsible for controling which strings acually requires translation.
    /// Use `Table.findUntranslated` to find out what requires translation and not. The service will not be called if there are no untranslated values
    /// - Note: The service provider does not check if `to` contains `from`
    /// - Parameters:
    ///   - texts: the texts to translate, each item in the array is used as the key in the returned `TextTransaltionTable`
    ///   - from: language if text in dictionary
    ///   - to: languages to translate into
    ///   - table: a table containing all translated (and original) texts
    /// - Returns: a completion publisher
    func translate(_ texts: [String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTranslationTable) -> FinishedPublisher
    /// Translate a text from one language to another
    /// The service provider is responsible for keeping cache if that's appropriate. For security reasons that feature should be configurable by the user.
    /// - Parameters:
    ///   - text: the text to translate
    ///   - from: the language of the text
    ///   - to: the language in which to translate into
    /// - Returns: a completion publisher
    func translate(_ text: String, from: LanguageKey, to: LanguageKey) -> TranslatedPublisher
}

/// TextTranslator provides a common interface for Text translation services implementing the `TextTranslationService` protocol.
final public class TextTranslator: ObservableObject {
    /// The text translation service provider
    public var service: TextTranslationService?
    /// Initializes a new instance
    /// - Parameter service: The text translation service provider
    public init(service: TextTranslationService?) {
        self.service = service
    }
    /// Translate all texts in a dictionary from one language to one or more languages
    /// If the supplied table is fully translated the method won't call the underlying service.
    /// - Note: If `to` contains `from`, `from` will be removed in `in`
    /// - Parameters:
    ///   - texts: dictionary to translate where the key can be anything and the string the text you wish to translate
    ///   - from: language if text in dictionary
    ///   - to: languages to translate into
    ///   - table: a table containing all translated (and original) texts
    /// - Returns: a completion publisher
    final public func translate(_ texts: [TranslationKey:String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTranslationTable = TextTranslationTable()) -> FinishedPublisher {
        guard let service = service else {
            return Fail(error: TextTranslatorError.missingService).eraseToAnyPublisher()
        }
        var to = to
        to.removeAll { $0 == from }
        if to.isEmpty {
            debugPrint("No strings requires translation (0 languages to translate into)")
            return CurrentValueSubject(table).eraseToAnyPublisher()
        }
        if table.hasUntranslatedValues(for: texts.map { $0.key }, in: to) == false {
            debugPrint("Strings already translated")
            return CurrentValueSubject(table).eraseToAnyPublisher()
        }
        return service.translate(texts, from: from, to: to, storeIn: table)
    }
    /// Translate all texts in an array from one language to one or more languages.
    /// If the supplied table is fully translated the method won't call the underlying service.
    /// - Note: If `to` contains `from`, `from` will be removed in `in`.
    /// - Parameters:
    ///   - texts: the texts to translate, each item in the array is used as the key in the returned `TextTransaltionTable`
    ///   - from: language if text in dictionary
    ///   - to: languages to translate into
    ///   - table: a table containing all translated (and original) texts
    /// - Returns: a completion publisher
    final public func translate(_ texts: [String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTranslationTable = TextTranslationTable()) -> FinishedPublisher {
        guard let service = service else {
            return Fail(error: TextTranslatorError.missingService).eraseToAnyPublisher()
        }
        var to = to
        to.removeAll { $0 == from }
        if to.isEmpty {
            debugPrint("No strings requires translation (0 languages to translate into)")
            return CurrentValueSubject(table).eraseToAnyPublisher()
        }
        if table.hasUntranslatedValues(for: texts, in: to) == false {
            debugPrint("Strings already translated")
            return CurrentValueSubject(table).eraseToAnyPublisher()
        }
        return service.translate(texts, from: from, to: to, storeIn: table)
    }
    /// Translate a text from one language to another.
    /// - Warning: This method might make service calls every time you call it.
    /// - Parameters:
    ///   - text: the text to translate
    ///   - from: the language of the text
    ///   - to: the language in which to translate into
    /// - Returns: a completion publisher
    final public func translate(_ text: String, from: LanguageKey, to: LanguageKey) -> TranslatedPublisher {
        guard let service = service else {
            return Fail(error: TextTranslatorError.missingService).eraseToAnyPublisher()
        }
        return service.translate(text, from: from, to: to)
    }
}
