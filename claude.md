# Trakt TV iOS App

## Technical Constraints

- **UIKit only** - No SwiftUI, no storyboards
- **Swift 6** with async/await
- **GRDB** for persistence (not Core Data/SwiftData)
- **iOS 17.0+** minimum deployment
- Pure programmatic UI

## Code Standards

- Use modern UIKit APIs (diffable data sources, compositional layouts)
- DocC-compatible documentation for public interfaces
- Follow Swift API design guidelines
- Include basic error handling in all network/database operations

## Architecture Rules

- ViewControllers handle their own navigation
- Service/manager pattern for API and database operations
- No complex coordinator patterns or unnecessary abstractions
- Design for offline-first where possible

## API Constraints

- Trakt API v2: https://trakt.docs.apiary.io
- Respect rate limit: 1000 calls/5 minutes
- Use OAuth 2.0 with PKCE for authentication
- Handle API errors gracefully

## Development Principles

- Prioritize simplicity over clever patterns
- Keep code concise and readable
- Avoid premature optimization
- Test on real devices when possible
