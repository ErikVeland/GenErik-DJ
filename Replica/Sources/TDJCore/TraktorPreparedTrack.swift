import Foundation

extension Track {
    /// Resolve an original reference for a deliberate load. Existing manual preparation takes priority.
    public func resolvingTraktorPreparation() -> Track {
        guard let original=traktorPreparation else { return self }
        var result=self
        if let grid=result.automaticBarGrid {
            result.preparation.grid=grid
            result.preparation.gridIsManual=false
        } else if !result.preparation.gridIsManual,result.preparation.gridWasEditedByUser != true,
            !result.preparation.gridLocked,let grid=original.normalized.grid {
            result.preparation.grid=grid
            result.preparation.gridIsManual=true
        }
        result.preparation.importKey(original.normalized.key, authority: .traktor)
        return result
    }
}
