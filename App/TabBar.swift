import Core
import SwiftUI

/// The two tabs at the bottom of the home screen and the Charts screen.
enum AppTab: String, CaseIterable {
  case today = "Today"
  case charts = "Charts"
}

/// The tab bar: two pill buttons, with colours for each sky, from `.tabs` in `design/gallery.css`.
/// The Charts screen has no sky of its own, so it uses the day colours.
struct TabBar: View {
  let current: AppTab
  var sky = SkyPhase.day
  let onSelect: (AppTab) -> Void

  var body: some View {
    HStack(spacing: 12) {
      ForEach(AppTab.allCases, id: \.self) { tab in
        tabButton(tab)
      }
    }
    .padding(.top, 6)
  }

  private func tabButton(_ tab: AppTab) -> some View {
    let isCurrent = tab == current
    let colors = TabColors.on(sky)
    return Button {
      if !isCurrent { onSelect(tab) }
    } label: {
      Text(tab.rawValue)
        .font(.baloo(19, .bold))
        .foregroundStyle(isCurrent ? colors.currentInk : colors.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Capsule().fill(isCurrent ? colors.currentFill : .clear))
        .overlay(Capsule().strokeBorder(isCurrent ? colors.currentBorder : colors.border, lineWidth: 3))
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(tab.rawValue)
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }
}

private struct TabColors {
  let ink: Color
  let border: Color
  let currentInk: Color
  let currentFill: Color
  let currentBorder: Color

  static func on(_ sky: SkyPhase) -> TabColors {
    switch sky {
    case .day:
      TabColors(ink: Theme.navy, border: Theme.navy, currentInk: Theme.navy, currentFill: .white, currentBorder: .white)
    case .night:
      TabColors(
        ink: Theme.cream, border: Theme.nightTab, currentInk: Theme.cream, currentFill: Theme.nightTab,
        currentBorder: Theme.nightTab)
    case .sunset:
      TabColors(
        ink: Theme.duskInk, border: Theme.duskInk, currentInk: Theme.duskInk, currentFill: Theme.duskInk.opacity(0.25),
        currentBorder: Theme.duskInk)
    case .sunrise:
      TabColors(ink: .white, border: .white, currentInk: Theme.navy, currentFill: .white, currentBorder: .white)
    }
  }
}
