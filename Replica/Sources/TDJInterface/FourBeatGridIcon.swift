import SwiftUI

struct FourBeatGridIcon: View {
    var body: some View {
        HStack(spacing: 4) { ForEach(0..<4, id: \.self) { _ in Rectangle().frame(width: 2, height: 20) } }.frame(
            width: 20, height: 20
        ).accessibilityHidden(true)
    }
}
