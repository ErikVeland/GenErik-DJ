import Foundation
import Observation

@MainActor @Observable
final class LibraryBrowserPlaylistSave {
    private(set) var isSaving=false
    @ObservationIgnored private var task:Task<Void,Never>?
    @ObservationIgnored private var token:UUID?

    @discardableResult
    func start(resolve:@escaping @Sendable () async throws -> [String],
               commit:@escaping @MainActor ([String]) throws -> Void,
               failed:@escaping @MainActor (Error) -> Void) -> Task<Void,Never>? {
        guard !isSaving else { return nil }
        let token=UUID();self.token=token;isSaving=true
        let current=Task { @MainActor [weak self] in
            do {
                let members=try await resolve()
                try Task.checkCancellation()
                guard self?.token == token else { return }
                try commit(members)
            } catch is CancellationError { }
            catch {
                guard self?.token == token else { return }
                failed(error)
            }
            guard let self,self.token == token else { return }
            self.token=nil;isSaving=false;task=nil
        }
        task=current;return current
    }
    func cancel() {
        token=nil
        let previous=task;task=nil;isSaving=false
        previous?.cancel()
    }
}
