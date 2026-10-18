#!/usr/bin/env swift
// scripts/sparkle_tool.swift
// Native Ed25519 key generator, signer, and verifier for Sparkle 2 distribution.
// Built with Apple CryptoKit (macOS 14.0+).

import Foundation
import CryptoKit

func printUsage() {
    print("""
    Usage: sparkle_tool.swift <command> [arguments]

    Commands:
      generate-keys
          Generate a fresh Ed25519 key pair for Sparkle 2 appcast signing.
      
      sign <file-path> <private-key-string-or-file>
          Generate a base64 sparkle:edSignature for the specified archive.
      
      verify <file-path> <signature-base64> <public-key-base64>
          Verify that an archive matches an Ed25519 signature.
    """)
}

let arguments = CommandLine.arguments

guard arguments.count >= 2 else {
    printUsage()
    exit(1)
}

let command = arguments[1]

switch command {
case "generate-keys":
    let privateKey = Curve25519.Signing.PrivateKey()
    let publicKey = privateKey.publicKey
    
    let privateBase64 = privateKey.rawRepresentation.base64EncodedString()
    let publicBase64 = publicKey.rawRepresentation.base64EncodedString()
    
    print("Sparkle 2 Ed25519 Key Pair Generated:")
    print("----------------------------------------------------------------")
    print("Public Key (SUPublicEDKey in Info.plist / appcast.xml):")
    print(publicBase64)
    print("----------------------------------------------------------------")
    print("Private Key (Store as SPARKLE_ED_KEY secret in GitHub Actions):")
    print(privateBase64)
    print("----------------------------------------------------------------")

case "sign":
    guard arguments.count >= 4 else {
        print("Error: sign requires <file-path> and <private-key>", to: &stderrStream)
        exit(1)
    }
    
    let filePath = arguments[2]
    let keyInput = arguments[3]
    
    let fileURL = URL(fileURLWithPath: filePath)
    guard let fileData = try? Data(contentsOf: fileURL) else {
        print("Error: Unable to read file at \(filePath)", to: &stderrStream)
        exit(1)
    }
    
    var privateKeyBase64 = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    // If keyInput points to a file, read from it
    if FileManager.default.fileExists(atPath: keyInput),
       let fileKey = try? String(contentsOfFile: keyInput, encoding: .utf8) {
        privateKeyBase64 = fileKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    guard let keyData = Data(base64Encoded: privateKeyBase64),
          let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) else {
        print("Error: Invalid base64 private key", to: &stderrStream)
        exit(1)
    }
    
    do {
        let signature = try privateKey.signature(for: fileData)
        print(signature.base64EncodedString())
    } catch {
        print("Error signing data: \(error)", to: &stderrStream)
        exit(1)
    }

case "verify":
    guard arguments.count >= 5 else {
        print("Error: verify requires <file-path>, <signature-base64>, and <public-key-base64>", to: &stderrStream)
        exit(1)
    }
    
    let filePath = arguments[2]
    let sigBase64 = arguments[3]
    let pubBase64 = arguments[4]
    
    let fileURL = URL(fileURLWithPath: filePath)
    guard let fileData = try? Data(contentsOf: fileURL),
          let sigData = Data(base64Encoded: sigBase64),
          let pubData = Data(base64Encoded: pubBase64),
          let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData) else {
        print("Error: Invalid file, signature, or public key", to: &stderrStream)
        exit(1)
    }
    
    if publicKey.isValidSignature(sigData, for: fileData) {
        print("VERIFIED")
        exit(0)
    } else {
        print("INVALID_SIGNATURE", to: &stderrStream)
        exit(1)
    }

case "--help", "-h":
    printUsage()
    exit(0)

default:
    print("Unknown command: \(command)", to: &stderrStream)
    printUsage()
    exit(1)
}

struct StderrStream: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
var stderrStream = StderrStream()
