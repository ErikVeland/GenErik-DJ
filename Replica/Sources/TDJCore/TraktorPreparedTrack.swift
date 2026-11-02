import Foundation

extension Track {
    /// Resolve an original reference for a deliberate load. Existing manual preparation takes priority.
    public func resolvingTraktorPreparation() -> Track {
        guard let original=traktorPreparation else { return self }
        var result=self
        if !result.preparation.gridIsManual, let grid=original.normalized.grid {
            result.preparation.grid=grid
            result.preparation.gridIsManual=true
        }
        if result.preparation.correctedKey == nil {
            result.preparation.correctedKey=original.normalized.key
        }
        return result
    }
}
