import Foundation
import Supabase

// MARK: - API Client

class APIClient {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }
    
    private init() {
        // TODO: Update for production
        #if DEBUG
        self.baseURL = "http://localhost:3000/api"
        #else
        self.baseURL = "https://your-api-domain.com/api"
        #endif
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Request Methods
    
    func request<T: Decodable>(_ endpoint: String,
                               method: HTTPMethod = .get,
                               body: Encodable? = nil,
                               responseType: T.Type) async throws -> T {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
                
            case 401:
                throw APIError.unauthorized
                
            case 404:
                throw APIError.notFound
                
            default:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.httpError(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // Convenience methods
    func get<T: Decodable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        try await request(endpoint, method: .get, responseType: responseType)
    }
    
    func post<T: Decodable>(_ endpoint: String, body: Encodable? = nil, responseType: T.Type) async throws -> T {
        try await request(endpoint, method: .post, body: body, responseType: responseType)
    }
    
    func put<T: Decodable>(_ endpoint: String, body: Encodable? = nil, responseType: T.Type) async throws -> T {
        try await request(endpoint, method: .put, body: body, responseType: responseType)
    }
    
    func delete<T: Decodable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        try await request(endpoint, method: .delete, responseType: responseType)
    }
    
    // For endpoints that don't return data
    func post(_ endpoint: String, body: Encodable? = nil) async throws {
        _ = try await request(endpoint, method: .post, body: body, responseType: EmptyResponse.self)
    }
    
    func put(_ endpoint: String, body: Encodable? = nil) async throws {
        _ = try await request(endpoint, method: .put, body: body, responseType: EmptyResponse.self)
    }
    
    func delete(_ endpoint: String) async throws {
        _ = try await request(endpoint, method: .delete, responseType: EmptyResponse.self)
    }
    
    // Update auth token
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(String)
    case httpError(Int)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please login again."
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return message
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
}

struct EmptyResponse: Codable {}
