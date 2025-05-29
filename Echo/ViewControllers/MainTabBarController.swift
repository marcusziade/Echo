import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupAppearance()
    }

    private func setupViewControllers() {
        let upNextVC = createPlaceholderViewController(
            title: "Up Next",
            systemImage: "play.circle.fill"
        )

        let searchVC = createPlaceholderViewController(
            title: "Search",
            systemImage: "magnifyingglass"
        )

        let libraryVC = createPlaceholderViewController(
            title: "Library",
            systemImage: "square.stack.fill"
        )

        let profileVC = createPlaceholderViewController(
            title: "Profile",
            systemImage: "person.circle.fill"
        )

        viewControllers = [upNextVC, searchVC, libraryVC, profileVC]
    }

    private func setupAppearance() {
        tabBar.tintColor = .systemRed

        // Configure tab bar appearance for iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func createPlaceholderViewController(title: String, systemImage: String)
        -> UINavigationController
    {
        let viewController = PlaceholderViewController(title: title)
        viewController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            selectedImage: UIImage(systemName: systemImage)
        )

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true

        return navigationController
    }
}

// MARK: - Placeholder View Controller
private final class PlaceholderViewController: UIViewController {
    private let titleText: String

    init(title: String) {
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationItem.title = titleText

        let label = UILabel()
        label.text = "\(titleText) - Coming Soon"
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // Add logout button for Profile tab
        if titleText == "Profile" {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Logout",
                style: .plain,
                target: self,
                action: #selector(logoutTapped)
            )
        }
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Logout", style: .destructive) { _ in
                do {
                    try TraktAuthManager.shared.logout()

                    // Post notification to handle logout in SceneDelegate
                    NotificationCenter.default.post(name: .userDidLogout, object: nil)
                } catch {
                    print("Logout error: \(error)")
                }
            })

        present(alert, animated: true)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
}
