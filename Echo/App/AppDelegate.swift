import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Setup database
        setupDatabase()

        return true
    }

    private func setupDatabase() {
        do {
            try DatabaseManager.shared.setup()
            print("✅ Database initialized successfully")

            // Run tests in DEBUG mode
            #if DEBUG
                DatabaseManager.shared.testModels()
            #endif

        } catch {
            print("❌ Failed to initialize database: \(error)")
            // In production, you might want to show an error to the user
            // or try to recover from this error
        }
    }
}
