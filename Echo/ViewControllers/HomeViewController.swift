import Combine
import UIKit

final class HomeViewController: UIViewController {

    // MARK: - Section
    enum Section: CaseIterable {
        case main
        case loading
    }
    
    // MARK: - Sort Options
    enum SortOption: String, CaseIterable {
        case airDate = "Air Date"
        case showTitle = "Show Title"
        case episodeNumber = "Episode"
        case progress = "Progress"
        
        var icon: String {
            switch self {
            case .airDate: return "calendar"
            case .showTitle: return "textformat.abc"
            case .episodeNumber: return "number"
            case .progress: return "chart.bar.fill"
            }
        }
    }

    // MARK: - UI Elements
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.separatorStyle = .none
        table.backgroundColor = .systemBackground
        table.contentInsetAdjustmentBehavior = .automatic
        return table
    }()

    private let emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let emptyStateImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "tv")
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No Episodes to Watch"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emptyStateSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Add shows to your library to see upcoming episodes"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Properties
    private var dataSource: UITableViewDiffableDataSource<Section, UpNextItem>!
    private var cancellables = Set<AnyCancellable>()
    private let viewModel = HomeViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupTableView()
        configureDataSource()
        setupBindings()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Task {
            await viewModel.checkAndPerformInitialSync()
        }
    }

    // MARK: - Setup
    private func setupUI() {
        title = "Up Next"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true

        // Add sync button
        let syncButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(syncButtonTapped)
        )
        
        // Add sort button
        let sortButton = UIBarButtonItem(
            image: UIImage(systemName: viewModel.sortOption.icon),
            style: .plain,
            target: self,
            action: #selector(sortButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [syncButton, sortButton]

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)

        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        emptyStateView.addSubview(emptyStateSubtitleLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Table View
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Empty State View
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Empty State Image
            emptyStateImageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 80),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 80),

            // Empty State Label
            emptyStateLabel.topAnchor.constraint(
                equalTo: emptyStateImageView.bottomAnchor, constant: 20),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),

            // Empty State Subtitle
            emptyStateSubtitleLabel.topAnchor.constraint(
                equalTo: emptyStateLabel.bottomAnchor, constant: 8),
            emptyStateSubtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateSubtitleLabel.trailingAnchor.constraint(
                equalTo: emptyStateView.trailingAnchor),
            emptyStateSubtitleLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),

            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.register(
            UpNextTableViewCell.self, forCellReuseIdentifier: UpNextTableViewCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
    }

    private func configureDataSource() {
        // Register loading cell
        tableView.register(LoadingTableViewCell.self, forCellReuseIdentifier: LoadingTableViewCell.identifier)
        
        dataSource = UITableViewDiffableDataSource<Section, UpNextItem>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, item in
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            
            if section == .loading {
                guard let cell = tableView.dequeueReusableCell(
                    withIdentifier: LoadingTableViewCell.identifier,
                    for: indexPath
                ) as? LoadingTableViewCell
                else {
                    return UITableViewCell()
                }
                cell.startAnimating()
                return cell
            } else {
                guard
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: UpNextTableViewCell.identifier,
                        for: indexPath
                    ) as? UpNextTableViewCell
                else {
                    return UITableViewCell()
                }
                cell.configure(with: item)
                return cell
            }
        }

        dataSource.defaultRowAnimation = .fade
    }

    private func setupBindings() {
        // Bind loading state
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
        
        // Bind syncing state
        viewModel.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncing in
                self?.navigationItem.rightBarButtonItems?.first?.isEnabled = !isSyncing
            }
            .store(in: &cancellables)
        
        // Bind items
        viewModel.$upNextItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSnapshot()
            }
            .store(in: &cancellables)
        
        // Bind loading more state
        viewModel.$isLoadingMore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSnapshot()
            }
            .store(in: &cancellables)
        
        // Bind sort option
        viewModel.$sortOption
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sortOption in
                self?.navigationItem.rightBarButtonItems?.last?.image = UIImage(systemName: sortOption.icon)
                self?.updateSnapshot()
            }
            .store(in: &cancellables)
    }

    // MARK: - Private Methods
    private func updateSnapshot() {
        let items = viewModel.sortedItems
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, UpNextItem>()
        
        if !items.isEmpty {
            snapshot.appendSections([.main])
            snapshot.appendItems(items, toSection: .main)
            
            // Add loading section if we're loading more and have more items
            if viewModel.isLoadingMore {
                snapshot.appendSections([.loading])
                // Create a dummy item for the loading cell
                let dummyItem = UpNextItem(
                    show: Show(traktId: -1, title: "Loading", year: nil, overview: nil, runtime: nil, status: nil, network: nil, updatedAt: nil, posterUrl: nil, backdropUrl: nil, tmdbId: nil),
                    nextEpisode: Episode(showId: -1, traktId: -1, season: 0, number: 0, title: nil, overview: nil, runtime: nil, airedAt: nil, watchedAt: nil),
                    progress: nil
                )
                snapshot.appendItems([dummyItem], toSection: .loading)
            }
        }

        // Use less aggressive animations for large datasets
        let animatingDifferences = items.count < 20
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences) { [weak self] in
            guard let self = self else { return }
            self.showEmptyState(items.isEmpty && !self.viewModel.isLoading)
        }
    }

    private func showEmptyState(_ show: Bool) {
        emptyStateView.isHidden = !show
        tableView.isHidden = show && !viewModel.isLoading
    }

    // MARK: - Actions
    @objc private func syncButtonTapped() {
        Task {
            await viewModel.syncUserShows()
        }
    }
    
    @objc private func sortButtonTapped() {
        let alertController = UIAlertController(
            title: "Sort By",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        for option in SortOption.allCases {
            let action = UIAlertAction(
                title: option.rawValue,
                style: .default,
                handler: { [weak self] _ in
                    self?.viewModel.updateSortOption(option)
                }
            )
            
            if option == viewModel.sortOption {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alertController.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        
        present(alertController, animated: true)
    }
}

// MARK: - UITableViewDelegate
extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        // Don't handle selection for loading cell
        if item.show.traktId == -1 { return }
        
        // TODO: Navigate to episode details
        print(
            "Selected: \(item.show.title) - S\(item.nextEpisode.season)E\(item.nextEpisode.number)")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        // Check if we're near the bottom (within 100 points)
        if offsetY > contentHeight - height - 100 {
            viewModel.loadMoreItems()
        }
    }
}

// MARK: - UpNextItem Extension for Hashable
extension UpNextItem: Hashable {
    static func == (lhs: UpNextItem, rhs: UpNextItem) -> Bool {
        lhs.show.id == rhs.show.id && lhs.nextEpisode.id == rhs.nextEpisode.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(show.id)
        hasher.combine(nextEpisode.id)
    }
}
