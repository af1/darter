import Foundation

/// CGKeyCode values for the default US ANSI keyboard bindings, plus a
/// display-name lookup used by the settings UI. Not layout-aware -- fine for
/// this app's fixed default bindings; users rebinding via KeyCaptureField
/// just get "Key <n>" for anything outside this table.
enum KeyCode {
    static let a: UInt16 = 0x00
    static let s: UInt16 = 0x01
    static let d: UInt16 = 0x02
    static let f: UInt16 = 0x03
    static let h: UInt16 = 0x04
    static let g: UInt16 = 0x05
    static let z: UInt16 = 0x06
    static let x: UInt16 = 0x07
    static let c: UInt16 = 0x08
    static let v: UInt16 = 0x09
    static let b: UInt16 = 0x0B
    static let q: UInt16 = 0x0C
    static let w: UInt16 = 0x0D
    static let e: UInt16 = 0x0E
    static let r: UInt16 = 0x0F
    static let y: UInt16 = 0x10
    static let t: UInt16 = 0x11
    static let one: UInt16 = 0x12
    static let two: UInt16 = 0x13
    static let three: UInt16 = 0x14
    static let four: UInt16 = 0x15
    static let six: UInt16 = 0x16
    static let five: UInt16 = 0x17
    static let equals: UInt16 = 0x18
    static let nine: UInt16 = 0x19
    static let seven: UInt16 = 0x1A
    static let minus: UInt16 = 0x1B
    static let eight: UInt16 = 0x1C
    static let zero: UInt16 = 0x1D
    static let rightBracket: UInt16 = 0x1E
    static let o: UInt16 = 0x1F
    static let u: UInt16 = 0x20
    static let leftBracket: UInt16 = 0x21
    static let i: UInt16 = 0x22
    static let p: UInt16 = 0x23
    static let l: UInt16 = 0x25
    static let j: UInt16 = 0x26
    static let quote: UInt16 = 0x27
    static let k: UInt16 = 0x28
    static let semicolon: UInt16 = 0x29
    static let backslash: UInt16 = 0x2A
    static let comma: UInt16 = 0x2B
    static let slash: UInt16 = 0x2C
    static let n: UInt16 = 0x2D
    static let m: UInt16 = 0x2E
    static let period: UInt16 = 0x2F
    static let tab: UInt16 = 0x30
    static let space: UInt16 = 0x31
    static let backtick: UInt16 = 0x32
    static let delete: UInt16 = 0x33
    static let escape: UInt16 = 0x35
    static let returnKey: UInt16 = 0x24

    private static let displayNames: [UInt16: String] = [
        a: "A", s: "S", d: "D", f: "F", h: "H", g: "G", z: "Z", x: "X",
        c: "C", v: "V", b: "B", q: "Q", w: "W", e: "E", r: "R", y: "Y",
        t: "T", one: "1", two: "2", three: "3", four: "4", six: "6",
        five: "5", equals: "=", nine: "9", seven: "7", minus: "-",
        eight: "8", zero: "0", rightBracket: "]", o: "O", u: "U",
        leftBracket: "[", i: "I", p: "P", l: "L", j: "J", quote: "'",
        k: "K", semicolon: ";", backslash: "\\", comma: ",", slash: "/",
        n: "N", m: "M", period: ".", tab: "Tab", space: "Space",
        backtick: "`", delete: "Delete", escape: "Esc", returnKey: "Return",
    ]

    static func displayName(for keyCode: UInt16) -> String {
        displayNames[keyCode] ?? "Key \(keyCode)"
    }
}
