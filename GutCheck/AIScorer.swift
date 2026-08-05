import Foundation

/// AI photo scoring: a photo of the stool goes to Claude (vision), which
/// returns a proposed 4C reading via a forced, strict tool call. The model
/// proposes, the owner corrects — the stored record is always owner-confirmed,
/// and the AI never writes to the record directly.
///
/// The API key lives in Secrets.plist (gitignored, copied into the app bundle
/// by an optional build step). No key means scoring is disabled and capture
/// falls back to manual chips. For a shipped app this call would go through a
/// backend proxy; a key in the bundle is a local-development convenience only.

struct AIScore {
    var reading: StoolReading
    /// Axis labels the owner should double-check (low confidence or unscorable).
    var uncertainAxes: [String]
    var isStool: Bool
}

enum AIScorerError: Error {
    case notConfigured
    case badResponse
    case api(String)
}

enum AIScorer {
    static let model = "claude-sonnet-5"

    static var apiKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = plist["ANTHROPIC_API_KEY"] as? String,
              !key.isEmpty
        else { return nil }
        return key
    }

    static var isConfigured: Bool { apiKey != nil }

    // The model is not a veterinarian and never diagnoses; it scores four
    // independent axes and abstains per-axis when the photo doesn't support
    // a judgment. Enum values match the app's Codable raw values exactly.
    private static let systemPrompt = """
        You score photographs of dog or cat stool for a pet-health tracking app. \
        You are not a veterinarian and never diagnose. Score four independent axes \
        using only the provided tool. Consistency maps to fecal scores: logs=2, \
        littleSoft=4, softServe=5, diarrhea=6, liquid=7, hard=1. For each axis give \
        a confidence from 0 to 1. If the image is not clearly stool, set is_stool \
        to false. If lighting, angle, or occlusion prevents assessing an axis, \
        return "unscorable" for that axis rather than guessing.
        """

    private static let toolDefinition: [String: Any] = [
        "name": "report_stool_score",
        "description": "Report the 4C score for the stool photo. Use unscorable for any axis the photo does not support.",
        "strict": true,
        "input_schema": [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "is_stool",
                "consistency", "consistency_confidence",
                "color", "color_confidence",
                "coating", "coating_confidence",
                "contents", "contents_confidence",
            ],
            "properties": [
                "is_stool": ["type": "boolean", "description": "True only if the image clearly shows animal stool"],
                "consistency": ["type": "string", "enum": ["logs", "littleSoft", "softServe", "diarrhea", "liquid", "hard", "unscorable"]],
                "consistency_confidence": ["type": "number"],
                "color": ["type": "string", "enum": ["brown", "green", "yellowOrange", "greyGreasy", "redStreaks", "whiteChalky", "blackTarry", "pinkPurple", "unscorable"]],
                "color_confidence": ["type": "number"],
                "coating": ["type": "string", "enum": ["none", "mucus", "greasy", "unscorable"]],
                "coating_confidence": ["type": "number"],
                "contents": ["type": "string", "enum": ["none", "riceSpecks", "grass", "hair", "foreignMaterial", "blood", "unscorable"]],
                "contents_confidence": ["type": "number"],
            ],
        ],
    ]

    static func score(_ imageData: Data) async throws -> AIScore {
        guard let key = apiKey else { throw AIScorerError.notConfigured }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "output_config": ["effort": "low"],
            "system": systemPrompt,
            "tools": [toolDefinition],
            "tool_choice": ["type": "tool", "name": "report_stool_score"],
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": imageData.base64EncodedString(),
                        ],
                    ],
                    ["type": "text", "text": "Score this photo on all four axes."],
                ],
            ]],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIScorerError.badResponse }
        guard http.statusCode == 200 else {
            let message = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            throw AIScorerError.api(message ?? "HTTP \(http.statusCode)")
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let toolUse = content.first(where: { ($0["type"] as? String) == "tool_use" }),
              let input = toolUse["input"] as? [String: Any]
        else { throw AIScorerError.badResponse }

        return parse(input)
    }

    /// Map the tool output onto a reading. Unscorable or low-confidence axes
    /// keep the manual default and get flagged for the owner to check.
    private static func parse(_ input: [String: Any]) -> AIScore {
        let isStool = input["is_stool"] as? Bool ?? false
        var reading = StoolReading.normal
        var uncertain: [String] = []
        let threshold = 0.6

        func axis<T: RawRepresentable>(_ key: String, _ label: String, as type: T.Type) -> T? where T.RawValue == String {
            let confidence = input["\(key)_confidence"] as? Double ?? 0
            guard let raw = input[key] as? String,
                  raw != "unscorable",
                  let value = T(rawValue: raw),
                  confidence >= threshold
            else {
                uncertain.append(label)
                return (input[key] as? String).flatMap { T(rawValue: $0) }
            }
            return value
        }

        if isStool {
            if let value = axis("consistency", "consistency", as: ConsistencyChoice.self) { reading.consistency = value }
            if let value = axis("color", "color", as: StoolColor.self) { reading.color = value }
            if let value = axis("coating", "coating", as: Coating.self) { reading.coating = value }
            if let value = axis("contents", "contents", as: Contents.self) { reading.contents = value }
        }

        return AIScore(reading: reading, uncertainAxes: uncertain, isStool: isStool)
    }
}
