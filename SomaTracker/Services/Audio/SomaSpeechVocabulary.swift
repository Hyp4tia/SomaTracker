//
//  SomaSpeechVocabulary.swift
//  SomaTracker
//
//  Words the recognizer has no reason to know: Egyptian dish names, delivery apps and venues, and
//  the dialect phrasings dictation reliably mangles.
//
//  Apple caps contextualStrings at 100 phrases total, so every entry here is a slot taken from
//  something else. Generic words are deliberately absent: "chicken", "rice" and "water" are in the
//  system vocabulary already, and biasing the recognizer toward them buys nothing. What earns a
//  slot is a word the Saudi-trained Arabic model would otherwise write as something else.
//

import Foundation

enum SomaSpeechVocabulary {
    /// Egyptian dishes and dialect food words.
    private static let dishes = [
        "كشري", "حواوشي", "فول مدمس", "طعمية", "ملوخية", "كفتة", "كبدة إسكندراني", "شاورما",
        "رز معمر", "فطير مشلتت", "ممبار", "بامية", "محشي كرنب", "ورق عنب", "فتة", "مكرونة بشاميل",
        "رقاق", "صيادية", "حمام محشي", "كوارع", "سجق بلدي", "بسطرمة", "طاجن", "مسقعة",
        "بصارة", "عدس بجبة", "شكشوكة", "شيش طاووق", "فراخ بانيه", "كبدة فراخ", "حمص بالطحينة", "سلطة بلدي",
        "حلاوة طحينية", "بسبوسة", "أم علي", "رز بلبن", "كنافة", "قطايف", "بلح الشام", "عصير قصب",
        "سوبيا", "كركديه",
    ]

    /// Venues, chains and delivery apps, in both scripts: dictation writes "بريد فاست" as
    /// "breakfast" and English brand names in Arabic letters, so both forms earn a slot.
    private static let venues = [
        "بريد فاست", "طلبات", "طلباتي", "إلمينوز", "أطلب", "إنستاشوب", "رابيت",
        "كشري التحرير", "أبو طارق", "سيد حنفي", "زووبا", "كوك دور", "جاد", "الفلفلة",
        "أبو السيد", "صبحي كابر", "أندريا", "الشبراوي", "كنتاكي", "بيتزا هت",
        "هارديز", "سيلانترو", "سبينس", "مترو ماركت",
        "Breadfast", "Talabat", "Elmenus", "Cook Door",
    ]

    /// Phrasings and quantities dictation gets wrong: connected words, Egyptian short forms that
    /// get normalised into MSA, and the portion sizes people actually say.
    private static let phrasings = [
        "شاي بلبن", "شاي بالنعناع", "كوباية مية", "كوبايتين مية", "ازازة مية",
        "نص كيلو", "ربع كيلو", "نص فرخة", "طبق وسط", "ساندوتش كبدة",
        "رغيف حواوشي", "طبق كشري", "عيش بلدي", "فطار", "غدا",
        "عشا", "سحور", "تحلية", "مشروبات",
    ]

    /// Units and logging verbs, kept from the original list: they carry the quantity in a spoken log.
    private static let units = [
        "جرام", "مل", "لتر", "كيلو", "شربت", "أكلت", "سعرات", "بروتين",
    ]

    /// Fed to `SFSpeechRecognitionRequest.contextualStrings`. Apple documents a maximum of 100
    /// phrases across the whole list.
    static var contextualStrings: [String] {
        dishes + venues + phrasings + units
    }
}
