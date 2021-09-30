import Foundation
import Combine

public typealias LanguageKey = String
public typealias TranslatedValue = String
public typealias TranslationKey = String

public protocol Translatable {
    var stringsForTranslation: [String] { get }
}
public extension Array where Element: Translatable {
    var stringsForTranslation: [String] {
        var arr = [String]()
        for s in self {
            arr.append(contentsOf: s.stringsForTranslation)
        }
        return arr
    }
}
public extension TextTransaltionTable {
    subscript(lang: LanguageKey, key: TranslationKey) -> String {
        get {
            if db[lang]?[key] != nil {
               return db[lang]?[key] ?? key
            }
            if let l = lang.split(separator: "-").first {
                if db[String(l)]?[key] != nil {
                   return db[String(l)]?[key] ?? key
                }
            }
            return key
        }
        set {
            if db[lang] == nil {
                db[lang] = [:]
            }
            db[lang]?[key] = newValue
        }
    }
    func exists(lang: LanguageKey, key: TranslationKey) -> Bool {
        return db[lang]?[key] != nil
    }
}
public protocol TextTransaltionTable {
    var db: [LanguageKey: [TranslationKey: TranslatedValue]] { get set }
    subscript(lang: LanguageKey, key: TranslationKey) -> String { get set }
}
public struct TranslatedString {
    public let language: LanguageKey
    public let key: TranslationKey
    public let value: TranslatedValue
    public init(language: LanguageKey, key: TranslationKey, value: TranslatedValue) {
        self.language = language
        self.key = key
        self.value = value
    }
}
public protocol TextTranslationService {
    typealias TranslatedPublisher = AnyPublisher<TranslatedString, Error>
    typealias FinishedPublisher = AnyPublisher<TextTransaltionTable, Error>
    typealias FinishedSubject = PassthroughSubject<TextTransaltionTable, Error>
    typealias TranslatedSubject = PassthroughSubject<TranslatedString, Error>
    @discardableResult func translate(_ texts: [TranslationKey:String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTransaltionTable) -> FinishedPublisher
    @discardableResult func translate(_ texts: [String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTransaltionTable) -> FinishedPublisher
    @discardableResult func translate(_ text: String, from: LanguageKey, to: LanguageKey) -> TranslatedPublisher
}

final public class TextTranslator: ObservableObject {
    private var service: TextTranslationService
    public init(service: TextTranslationService) {
        self.service = service
    }
    @discardableResult final public func translate(_ texts: [TranslationKey:String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTransaltionTable) -> TextTranslationService.FinishedPublisher {
        return service.translate(texts, from: from, to: to, storeIn: table)
    }
    @discardableResult final public func translate(_ texts: [String], from: LanguageKey, to: [LanguageKey], storeIn table: TextTransaltionTable) -> TextTranslationService.FinishedPublisher {
        return service.translate(texts, from: from, to: to, storeIn: table)
    }
    final public func translate(_ text: String, from: LanguageKey, to: LanguageKey) -> TextTranslationService.TranslatedPublisher {
        return service.translate(text, from: from, to: to)
    }
}
