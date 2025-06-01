import Combine
import Foundation
import GRDB

final class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var upNextItems: [UpNextItem] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var sortOption: HomeViewController.SortOption = .airDate
    @Published var isLoadingMore = false
    
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let traktService: TraktService
    private let batchSyncService: BatchSyncService
    private let databaseManager: DatabaseManager
    private let databaseObservationService: DatabaseObservationService
    
    // MARK: - Computed Properties
    var sortedItems: [UpNextItem] {
        upNextItems
    }
    
    var isEmpty: Bool {
        upNextItems.isEmpty
    }
    
    // Cache control
    private var hasPerformedInitialLoad = false
    private var lastSyncDate: Date?
    
    // Pagination
    private let pageSize = 8
    private var currentPage = 0
    private var hasMoreItems = true
    private var allUpNextItems: [UpNextItem] = []
    
    // MARK: - Init
    init(
        traktService: TraktService = .shared,
        batchSyncService: BatchSyncService = .shared,
        databaseManager: DatabaseManager = .shared,
        databaseObservationService: DatabaseObservationService = .shared
    ) {
        self.traktService = traktService
        self.batchSyncService = batchSyncService
        self.databaseManager = databaseManager
        self.databaseObservationService = databaseObservationService
        
        setupObservations()
    }
    
    // MARK: - Public Methods
    func checkAndPerformInitialSync() async {
        guard let db = databaseManager.reader else { return }
        
        // Only sync if we haven't already loaded or if it's been a while
        if hasPerformedInitialLoad {
            // Check if we should perform a background sync
            if let lastSync = lastSyncDate,
               Date().timeIntervalSince(lastSync) < 300 { // 5 minutes
                return
            }
            
            // Perform background sync without showing loading indicator
            Task {
                await performBackgroundSync()
            }
            return
        }
        
        hasPerformedInitialLoad = true
        
        do {
            let showCount = try await db.read { db in
                try Show.fetchCount(db)
            }
            
            if showCount == 0 {
                print("📱 No shows in database, performing initial sync...")
                await syncUserShows()
            } else {
                // Data exists, perform background sync to get latest
                Task {
                    await performBackgroundSync()
                }
            }
        } catch {
            print("❌ Failed to check database: \(error)")
        }
    }
    
    private func performBackgroundSync() async {
        guard !isSyncing else { return }
        
        do {
            await MainActor.run {
                isSyncing = true
            }
            
            // Sync only shows that need updates
            let allWatchedShows = try await traktService.getAllWatchedShows()
            
            if !allWatchedShows.isEmpty {
                let importResult = try await batchSyncService.importSearchResults(
                    allWatchedShows.map {
                        TraktSearchResult(type: "show", score: nil, show: $0, movie: nil)
                    }
                )
                
                if importResult.importedShows > 0 || importResult.updatedShows > 0 {
                    // Only sync episodes for new or updated shows
                    guard let db = databaseManager.reader else { return }
                    
                    let recentlyUpdatedShows = try await db.read { db in
                        try Show
                            .filter(Column("updated_at") > Date().addingTimeInterval(-3600)) // Last hour
                            .fetchAll(db)
                            .compactMap { $0.id }
                    }
                    
                    if !recentlyUpdatedShows.isEmpty {
                        _ = try await batchSyncService.syncMultipleShows(
                            showIds: recentlyUpdatedShows
                        )
                    }
                    
                    // Update images for shows missing them
                    Task {
                        try? await batchSyncService.updateMissingImages()
                    }
                }
            }
            
            lastSyncDate = Date()
            
        } catch {
            print("❌ Background sync failed: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    func syncUserShows() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            if upNextItems.isEmpty {
                isLoading = true
            }
        }
        
        do {
            // Get ALL watched shows from user's account
            let allWatchedShows = try await traktService.getAllWatchedShows()
            print("📺 Found \(allWatchedShows.count) watched shows in user's account")
            
            if !allWatchedShows.isEmpty {
                // Import shows to database (without images initially)
                let importResult = try await batchSyncService.importSearchResults(
                    allWatchedShows.map {
                        TraktSearchResult(type: "show", score: nil, show: $0, movie: nil)
                    }
                )
                
                print("✅ Imported \(importResult.importedShows) new shows, updated \(importResult.updatedShows)")
                
                // Immediately fetch images for the imported shows
                print("🎬 Fetching images for imported shows...")
                try? await batchSyncService.updateMissingImages()
                
                // Get all show IDs from database
                guard let db = databaseManager.reader else { return }
                
                let showIds = try await db.read { db in
                    try Show
                        .order(Column("updated_at").desc ?? Column("id"))
                        .fetchAll(db)
                        .compactMap { $0.id }
                }
                
                // Sync all shows to get complete up next data
                if !showIds.isEmpty {
                    print("🔄 Syncing \(showIds.count) shows with episodes...")
                    
                    let batchResult = try await batchSyncService.syncMultipleShows(
                        showIds: showIds
                    )
                    
                    print("✅ Synced \(batchResult.successCount) shows successfully")
                }
            }
            
        } catch {
            print("❌ Failed to sync user shows: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
            isLoading = false
        }
    }
    
    func updateSortOption(_ option: HomeViewController.SortOption) {
        sortOption = option
        // Re-sort all items and reset pagination
        allUpNextItems = sortItems(allUpNextItems)
        currentPage = 0
        hasMoreItems = true
        loadFirstPage()
    }
    
    func loadMoreItems() {
        guard !isLoadingMore && hasMoreItems else { return }
        
        isLoadingMore = true
        
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, allUpNextItems.count)
        
        if startIndex < allUpNextItems.count {
            let newItems = Array(allUpNextItems[startIndex..<endIndex])
            upNextItems.append(contentsOf: newItems)
            currentPage += 1
            
            // Check if we have more items
            hasMoreItems = endIndex < allUpNextItems.count
        } else {
            hasMoreItems = false
        }
        
        isLoadingMore = false
    }
    
    private func loadFirstPage() {
        upNextItems = []
        currentPage = 0
        
        let endIndex = min(pageSize, allUpNextItems.count)
        if endIndex > 0 {
            upNextItems = Array(allUpNextItems[0..<endIndex])
            currentPage = 1
            hasMoreItems = endIndex < allUpNextItems.count
        } else {
            hasMoreItems = false
        }
    }
    
    // MARK: - Private Methods
    private func setupObservations() {
        databaseObservationService.observeUpNextEpisodes()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to observe up next episodes: \(error)")
                    }
                },
                receiveValue: { [weak self] items in
                    guard let self = self else { return }
                    // Store all items and apply sorting
                    self.allUpNextItems = self.sortItems(items)
                    // Reset pagination
                    self.currentPage = 0
                    self.hasMoreItems = true
                    // Load first page
                    self.loadFirstPage()
                }
            )
            .store(in: &cancellables)
    }
    
    private func sortItems(_ items: [UpNextItem]) -> [UpNextItem] {
        switch sortOption {
        case .airDate:
            return items.sorted { item1, item2 in
                guard let date1 = item1.nextEpisode.airedAt,
                      let date2 = item2.nextEpisode.airedAt else {
                    return false
                }
                return date1 < date2
            }
        case .showTitle:
            return items.sorted { $0.show.title.localizedCaseInsensitiveCompare($1.show.title) == .orderedAscending }
        case .episodeNumber:
            return items.sorted { item1, item2 in
                if item1.show.title == item2.show.title {
                    if item1.nextEpisode.season == item2.nextEpisode.season {
                        return item1.nextEpisode.number < item2.nextEpisode.number
                    }
                    return item1.nextEpisode.season < item2.nextEpisode.season
                }
                return item1.show.title.localizedCaseInsensitiveCompare(item2.show.title) == .orderedAscending
            }
        case .progress:
            return items.sorted { item1, item2 in
                let progress1 = item1.progress?.progressPercentage ?? 0
                let progress2 = item2.progress?.progressPercentage ?? 0
                return progress1 > progress2
            }
        }
    }
}
