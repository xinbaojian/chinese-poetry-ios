import Foundation

struct PoemSummary: Codable {
    let total: Int
    let categories: [String: Int]
}

struct PoemListResponse: Decodable {
    let poems: [Poem]
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case poems, total, page
        case perPage = "per_page"
    }
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
        poems.filter { Int($0.grade) == grade }
    }

    nonisolated static func filter(poems: [Poem], byCategory category: String) -> [Poem] {
        poems.filter { $0.category == category }
    }

    nonisolated static func search(poems: [Poem], query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        return poems.filter {
            $0.title.contains(query) ||
            $0.poetName.contains(query) ||
            $0.paragraphs.contains { $0.contains(query) }
        }
    }

    // MARK: - API 加载

    static func fetchPoems(keyword: String? = nil,
                           dynasty: String? = nil,
                           category: String? = nil,
                           grade: Int? = nil,
                           page: Int = 1,
                           perPage: Int = 100) async throws -> PoemListResponse {
        var params: [String] = ["page=\(page)", "per_page=\(perPage)"]
        if let keyword, let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            params.append("keyword=\(encoded)")
        }
        if let dynasty, let encoded = dynasty.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            params.append("dynasty=\(encoded)")
        }
        if let category, let encoded = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            params.append("category=\(encoded)")
        }
        if let grade { params.append("grade=\(grade)") }
        let path = "/poems?\(params.joined(separator: "&"))"
        return try await APIClient.shared.request(path)
    }

    static func fetchAllPoems() async throws -> [Poem] {
        var allPoems: [Poem] = []
        var page = 1
        let perPage = 100
        while true {
            let response = try await fetchPoems(page: page, perPage: perPage)
            allPoems.append(contentsOf: response.poems)
            if page * perPage >= response.total { break }
            page += 1
        }
        return allPoems
    }
}

enum PoemError: Error {
    case fileNotFound
}
