// Models/Card.swift
import Foundation

enum Suit: String, CaseIterable, Codable { case clubs, diamonds, hearts, spades }
enum Rank: Int, CaseIterable, Codable { case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace }

struct Card: Hashable, Codable { let rank: Rank; let suit: Suit }

extension Card: Equatable {
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }
}
