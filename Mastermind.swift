import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CreateGameResponse: Codable {
    let game_id: String
}

struct GuessRequest: Codable {
    let game_id: String
    let guess: String
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}

struct ErrorResponse: Codable {
    let error: String
}

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case noData
    case decodingError(Error)
    case apiError(String)
    case unexpectedStatusCode(Int)
}

class APIService {
    private let baseURL = "https://mastermind.darkube.app"
    private var currentGameID: String?

    func startGame(completion: @escaping (Result<String, APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unexpectedStatusCode(0)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                if httpResponse.statusCode == 200 {
                    let gameResponse = try JSONDecoder().decode(CreateGameResponse.self, from: data)
                    self.currentGameID = gameResponse.game_id
                    completion(.success(gameResponse.game_id))
                } else {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    completion(.failure(.apiError("API Error (HTTP \(httpResponse.statusCode)): \(errorResponse.error)")))
                }
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }

    func makeGuess(gameID: String, guess: String, completion: @escaping (Result<GuessResponse, APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/guess") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let guessPayload = GuessRequest(game_id: gameID, guess: guess)
        do {
            request.httpBody = try JSONEncoder().encode(guessPayload)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unexpectedStatusCode(0)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                if httpResponse.statusCode == 200 {
                    let guessResponse = try JSONDecoder().decode(GuessResponse.self, from: data)
                    completion(.success(guessResponse))
                } else {
                     let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                     completion(.failure(.apiError("API Error (HTTP \(httpResponse.statusCode)): \(errorResponse.error)")))
                }
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }

    func deleteGame(gameID: String, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard !gameID.isEmpty else {
             // No game to delete, or game ID was not set, consider this a success in terms of cleanup
            completion(.success(()))
            return
        }
        guard let url = URL(string: "\(baseURL)/game/\(gameID)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unexpectedStatusCode(0)))
                return
            }

            if httpResponse.statusCode == 204 {
                self.currentGameID = nil
                completion(.success(()))
            } else if httpResponse.statusCode == 404 { // Game already deleted or never existed
                self.currentGameID = nil
                completion(.success(())) // Treat as success for cleanup
            }
            else {
                if let data = data, !data.isEmpty {
                    do {
                        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        completion(.failure(.apiError("API Error (HTTP \(httpResponse.statusCode)): \(errorResponse.error)")))
                    } catch {
                         completion(.failure(.apiError("API Error (HTTP \(httpResponse.statusCode)): Could not parse error message. Status: \(httpResponse.statusCode)")))
                    }
                } else {
                     completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                }
            }
        }
        task.resume()
    }

    func getCurrentGameID() -> String? {
        return self.currentGameID
    }
}

class MastermindGame {
    private let apiService = APIService()
    private var gameID: String?
    private let semaphore = DispatchSemaphore(value: 0)

    private func handleExit() {
        print("\nExiting game...")
        if let currentGameID = apiService.getCurrentGameID() {
            apiService.deleteGame(gameID: currentGameID) { result in
                switch result {
                case .success:
                    print("Game session successfully deleted.")
                case .failure(let error):
                    print("Could not delete game session: \(error)")
                }
                self.semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 10)
        } else {
            print("No active game session to delete.")
        }
        exit(0)
    }

    private func isValidGuess(_ input: String) -> Bool {
        guard input.count == 4 else { return false }
        for char in input {
            guard let digit = Int(String(char)), digit >= 1 && digit <= 6 else {
                return false
            }
        }
        return true
    }

    func play() {
        print("Welcome to Mastermind! 🎲")
        print("Starting a new game with the server...")

        apiService.startGame { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let id):
                self.gameID = id
                print("Game started successfully. Your Game ID is: \(id)")
                print("The code is 4 digits long. Each digit is between 1 and 6.")
                print("Type your guess (e.g., 1234) or type 'exit' to quit at any time.")
            case .failure(let error):
                print("🚨 Error starting game: \(error)")
                print("Please check your internet connection and the API server status.")
                self.handleExit()
            }
            self.semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)

        guard gameID != nil else {
            print("Failed to initialize game. Exiting.")
            return
        }

        var attempts = 0
        while true {
            attempts += 1
            print("\nAttempt \(attempts): Enter your 4-digit guess: ", terminator: "")
            guard let userInput = readLine() else {
                print("Invalid input. Please try again.")
                continue
            }

            if userInput.lowercased() == "exit" {
                handleExit()
            }

            guard isValidGuess(userInput) else {
                print("Invalid guess format. Please enter exactly 4 digits, each between 1 and 6 (e.g., 1122).")
                continue
            }

            guard let currentGID = self.gameID else {
                print("Critical error: Game ID lost. Exiting.")
                handleExit()
                return
            }

            apiService.makeGuess(gameID: currentGID, guess: userInput) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let guessResponse):
                    print("Feedback: \(guessResponse.black)B \(guessResponse.white)W")
                    if guessResponse.black == 4 {
                        print("\n🎉 Congratulations! You guessed the code \(userInput) correctly in \(attempts) attempts! 🎉")
                        self.handleExit()
                    }
                case .failure(let error):
                    print("🚨 Error making guess: \(error)")
                    if case .apiError(let msg) = error, msg.contains("Game not found") {
                        print("It seems the game session on the server was lost. Please restart the game.")
                        self.gameID = nil
                        self.handleExit()
                    }
                }
                self.semaphore.signal()
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
    }
}

let game = MastermindGame()
game.play()