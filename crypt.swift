// AES-256-GCM envelope compatible with crypt.py. The key comes only from env.
import Foundation
import CryptoKit
let args = CommandLine.arguments
guard args.count == 4,
      let encoded = ProcessInfo.processInfo.environment["ECHO_KEY_B64"],
      let keyBytes = Data(base64Encoded: encoded), keyBytes.count == 32 else {
    fatalError("Usage: crypt.swift seal|open input output; requires ECHO_KEY_B64")
}
let magic = Data("ECHOENC1".utf8)
let key = SymmetricKey(data: keyBytes)
let input = try Data(contentsOf: URL(fileURLWithPath: args[2]))
let result: Data
if args[1] == "seal" {
    let box = try AES.GCM.seal(input, using: key, authenticating: magic)
    guard let combined = box.combined else { fatalError("Cannot encode ciphertext") }
    result = magic + combined
} else if args[1] == "open" {
    guard input.prefix(magic.count) == magic else { fatalError("Invalid encrypted envelope") }
    let box = try AES.GCM.SealedBox(combined: input.dropFirst(magic.count))
    result = try AES.GCM.open(box, using: key, authenticating: magic)
} else { fatalError("Unknown encryption operation") }
try result.write(to: URL(fileURLWithPath: args[3]), options: .atomic)
