// Store.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import os

private let log = Logger(subsystem: "com.excelano.peilung", category: "store")

/// The App Group shared by the watch app and its widget.
enum AppGroup {
    static let id = "group.com.excelano.peilung"

    /// Application Support inside the group container, so the widget reads what the app writes.
    static var applicationSupport: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
            .appending(path: "Library/Application Support") ?? .applicationSupportDirectory
    }
}

/// One Codable value kept as a JSON file in Application Support.
struct Store<Value: Codable> {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(name: String, in folder: URL = .applicationSupportDirectory) {
        self.init(url: folder.appending(path: "\(name).json"))
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value?) {
        do {
            guard let value else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            log.error("Saving \(url.lastPathComponent, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}
