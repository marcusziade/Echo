import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        // Check authentication status and set appropriate root view controller
        if TraktAuthManager.shared.isAuthenticated {
            showMainApp()
        } else {
            showAuthScreen()
        }

        window?.makeKeyAndVisible()

        // Listen for logout notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .userDidLogout,
            object: nil
        )

        // Handle URL callback from OAuth
        if let urlContext = connectionOptions.urlContexts.first {
            handleURL(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleURL(url)
    }

    // MARK: - Navigation
    private func showAuthScreen() {
        let authVC = AuthViewController()
        authVC.delegate = self
        window?.rootViewController = authVC
    }

    private func showMainApp() {
        let mainTabBarController = MainTabBarController()
        window?.rootViewController = mainTabBarController
    }

    @objc private func handleLogout() {
        // Animate transition to auth screen
        guard let window = window else { return }

        let authVC = AuthViewController()
        authVC.delegate = self

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: {
                window.rootViewController = authVC
            }
        )
    }

    private func handleURL(_ url: URL) {
        // OAuth callback URLs will be handled by ASWebAuthenticationSession
        // This is here for completeness and future deep linking support
        guard url.scheme == "echo-trakt" else { return }
        print("Received URL: \(url)")
    }
}

// MARK: - AuthViewControllerDelegate
extension SceneDelegate: AuthViewControllerDelegate {
    func authViewControllerDidAuthenticate(_ controller: AuthViewController) {
        // Animate transition to main app
        guard let window = window else { return }

        let mainTabBarController = MainTabBarController()

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: {
                window.rootViewController = mainTabBarController
            }
        )
    }
}
