struct NoteImportItem: Codable {
    let filename: String
    let file_id: String
    let title: String
    let answer: String
    private let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case filename
        case file_id
        case title
        case answer
        case metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filename = try container.decode(String.self, forKey: .filename)
        file_id = try container.decode(String.self, forKey: .file_id)
        title = try container.decode(String.self, forKey: .title)
        answer = try container.decode(String.self, forKey: .answer)
        metadata = try? container.decode([String: String].self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filename, forKey: .filename)
        try container.encode(file_id, forKey: .file_id)
        try container.encode(title, forKey: .title)
        try container.encode(answer, forKey: .answer)
        if let metadata = metadata {
            try container.encode(metadata, forKey: .metadata)
        }
    }
}
