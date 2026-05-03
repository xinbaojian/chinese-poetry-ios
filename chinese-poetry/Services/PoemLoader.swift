import Foundation

struct PoemLoader {
    static func loadPoems() throws -> [Poem] {
        guard let url = Bundle.main.url(forResource: "poems", withExtension: "json") else {
            throw PoemError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Poem].self, from: data)
    }

    static func loadCategoryPoems(category: String) async throws -> [Poem] {
        let fileName: String
        switch category {
        case "唐诗": fileName = "poems_tang"
        case "宋词": fileName = "poems_songci"
        default: return try await Task.detached { try loadPoems() }.value
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw PoemError.fileNotFound
        }

        return try await Task.detached {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Poem].self, from: data)
        }.value
    }

    static func filter(poems: [Poem], byGrade grade: Int) -> [Poem] {
        poems.filter { $0.grade == grade }
    }

    static func filter(poems: [Poem], byCategory category: String) -> [Poem] {
        poems.filter { $0.category == category }
    }

    static func search(poems: [Poem], query: String) -> [Poem] {
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
