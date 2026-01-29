//
//  Repository.swift
//  IntentTodo
//

@_exported import Domain

/// Repository module containing data access layer protocols and implementations.
///
/// This module provides:
/// - `TodoRepositoryProtocol`: The interface for todo data access
/// - `MockTodoRepository`: In-memory implementation for testing
/// - `SwiftDataTodoRepository`: Persistent implementation using SwiftData
/// - `RepositoryError`: Error types for repository operations
public enum Repository {
    /// Module version for debugging purposes.
    public static let version = "1.0.0"
}
