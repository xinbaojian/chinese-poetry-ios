import Foundation

struct PoemSummary: Codable {
    let total: Int
    let categories: [String: Int]
}

struct PoemLoader {
    nonisolated static func loadPoems() throws -> [Poem] {
        guard let url = Bundle.main.url(forResource: "poems", withExtension: "json") else {
            throw PoemError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Poem].self, from: data)
    }

    static func loadSummary() -> PoemSummary {
        guard let url = Bundle.main.url(forResource: "poem_summary", withExtension: "json") else {
            return PoemSummary(total: 0, categories: [:])
        }
        guard let data = try? Data(contentsOf: url),
              let summary = try? JSONDecoder().decode(PoemSummary.self, from: data) else {
            return PoemSummary(total: 0, categories: [:])
        }
        return summary
    }

    nonisolated static func loadCategoryPoems(category: String) async throws -> [Poem] {
        let poems = try await Task.detached { try loadPoems() }.value
        return filter(poems: poems, byCategory: category)
    }

    nonisolated static func filter(poems: [Poem], byGrade grade: Int) -> [Poem] {
        poems.filter { $0.grade == grade }
    }

    nonisolated static func filter(poems: [Poem], byCategory category: String) -> [Poem] {
        poems.filter { $0.category == category }
    }

    nonisolated static func search(poems: [Poem], query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        return poems.filter {
            $0.title.contains(query) ||
            $0.author.contains(query) ||
            $0.paragraphs.contains { $0.contains(query) }
        }
    }
}

enum PoemError: Error {
    case fileNotFound
}
