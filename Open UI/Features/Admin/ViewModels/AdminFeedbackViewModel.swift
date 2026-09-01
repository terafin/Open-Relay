import Foundation

/// ViewModel for the Admin Feedback History (Evaluations) screen.
@Observable
final class AdminFeedbackViewModel {

    // MARK: - State

    var items: [FeedbackItem] = []
    var total: Int = 0
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String? = nil

    // MARK: - Pagination

    private var currentPage = 1
    private let pageSize = 20

    var hasMorePages: Bool { items.count < total }

    // MARK: - Private

    private weak var apiClient: APIClient?

    // MARK: - Configure

    func configure(apiClient: APIClient?) {
        self.apiClient = apiClient
    }

    // MARK: - Load (first page)

    func loadFeedbacks() async {
        guard let api = apiClient else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 1
        do {
            let response = try await api.listFeedbacks(page: 1, limit: pageSize)
            items = response.items
            total = response.total
        } catch {
            let apiError = APIError.from(error)
            errorMessage = apiError.errorDescription ?? "Failed to load feedback history."
        }
        isLoading = false
    }

    // MARK: - Load More (pagination)

    func loadMore() async {
        guard !isLoadingMore, hasMorePages, let api = apiClient else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        do {
            let response = try await api.listFeedbacks(page: nextPage, limit: pageSize)
            items.append(contentsOf: response.items)
            total = response.total
            currentPage = nextPage
        } catch {
            // silently ignore load-more errors
        }
        isLoadingMore = false
    }

    // MARK: - Delete

    func deleteFeedback(id: String) async {
        guard let api = apiClient else { return }
        do {
            try await api.deleteFeedback(id: id)
            items.removeAll { $0.id == id }
            if total > 0 { total -= 1 }
        } catch {
            // silently ignore — item stays in list if delete fails
        }
    }

    // MARK: - Load Detail (fetches full snapshot)

    func loadDetail(id: String) async -> FeedbackItem? {
        guard let api = apiClient else { return nil }
        do {
            return try await api.getFeedback(id: id)
        } catch {
            return nil
        }
    }
}
