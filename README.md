# Mastermind Terminal Game

This project implements the classic Mastermind game as a terminal application using Swift. Players can try to guess a secret 4-digit code, with each digit being between 1 and 6. The game provides feedback after each guess in the form of "black" and "white" pegs, indicating correct digits in the correct position and correct digits in the wrong position, respectively.

The game interacts with a remote API to manage game sessions and validate guesses.

---

## Game Rules

* **Code Format**: The secret code is always 4 digits long.
* **Digit Range**: Each digit in the code is a number between 1 and 6 (inclusive).
* **Feedback**: After each guess, you'll receive feedback:
    * **B (Black Pegs)**: The number of digits that are correct in both value and position.
    * **W (White Pegs)**: The number of digits that are correct in value but are in the wrong position.

### Example

Let's say the secret code is `1234`.

* If you guess `1235`, the feedback will be `3B 0W`. (Digits `1`, `2`, and `3` are correct and in the correct position).
* If you guess `4321`, the feedback will be `0B 4W`. (Digits `4`, `3`, `2`, and `1` are all correct, but none are in their original position).

---

## Technical Requirements

* **Language**: Swift
* **Environment**: Executable in a terminal.
* **API Integration**: Uses the Mastermind API located at `https://mastermind.darkube.app/docs/index.html`.
* **Error Handling**: Robust error management for API communication and user input.
* **Exit Command**: The game can be exited at any point by typing `exit`.

---

## How to Play

1.  **Clone the repository**.
    ```bash
    git clone https://github.com/mhdsdt/mobile-programming-hw2.git
    ```
2.  **Navigate to the project directory** in your terminal.
    ```bash
    cd mobile-programming-hw2
    ```
3.  **Run the Swift application**:
    ```bash
    swift Mastermind.swift
    ```
4.  The game will start and attempt to create a new session with the Mastermind API.
5.  **Enter your 4-digit guesses** when prompted. Each digit must be between 1 and 6.
    * Example: `1234`
6.  The game will provide feedback in `NB NW` format (e.g., `2B 1W`).
7.  **Continue guessing** until you correctly identify the code (4B 0W).
8.  To **quit the game** at any time, type `exit` and press Enter. The game will attempt to delete the active session from the server.

---

## Code Structure

* **`APIService`**: This class handles all communication with the Mastermind API, including starting a new game, making guesses, and deleting game sessions. It defines `Codable` structs for API request/response bodies and an `APIError` enum for comprehensive error handling.
* **`MastermindGame`**: This class orchestrates the game logic. It manages the game flow, handles user input, validates guesses, and interacts with the `APIService`. It also includes an `handleExit()` function to gracefully terminate the game and clean up the server session.

---

## Error Handling

The game includes various error handling mechanisms:

* **API Errors**: Catches and reports issues related to network requests, invalid URLs, missing data, and API-specific errors (e.g., "Game not found").
* **Input Validation**: Ensures that user guesses are 4 digits long and consist only of numbers between 1 and 6.
* **Game Session Management**: Attempts to delete the game session on the server when the player exits or successfully guesses the code. It also handles cases where the server-side game session might be lost.
