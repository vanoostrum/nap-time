import Core
import NapTimeStore
import OSLog
import SwiftUI
import UIKit

/// Loads the family store, then shows "Add your child" when there is no child, or the home screen
/// and the Charts screen with their tab bar.
struct RootView: View {
  let mode: AppMode

  @State private var phase = Phase.loading
  /// The child chosen on this phone. `SelectedChild` decides which child the home screen shows.
  @State private var selectedID: Child.ID?
  @State private var cover: Cover?
  @State private var tab = AppTab.today

  private enum Phase {
    case loading
    case failed
    case ready(FamilyStore)
  }

  private enum Cover: Identifiable {
    case addAnother
    case edit(Child.ID)
    case sleep(SleepFormMode)

    var id: String {
      switch self {
      case .addAnother: "add-another"
      case .edit(let id): id.uuidString
      case .sleep(.new(_, let childID)): "new-sleep-\(childID.uuidString)"
      case .sleep(.edit(let sleep)): "edit-sleep-\(sleep.id.uuidString)"
      case .sleep(.wokeEarlier(let sleep)): "woke-earlier-\(sleep.id.uuidString)"
      case .sleep(.runningStart(let sleep)): "running-start-\(sleep.id.uuidString)"
      }
    }
  }

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "FamilyStore")
  private static let selectedChildKey = "selectedChildID"

  /// The Gregorian calendar in English, with 24-hour times and Monday first, in the time zone of the mode.
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_GB")
    calendar.firstWeekday = 2
    if case .test(let environment) = mode { calendar.timeZone = environment.timeZone }
    return calendar
  }

  /// The fixed clock of test mode, or `nil` in the normal mode.
  private var fixedNow: Date? {
    if case .test(let environment) = mode { environment.now } else { nil }
  }

  private var today: BirthDate { BirthDate(fixedNow ?? Date(), in: calendar) }

  var body: some View {
    content
      .environment(\.locale, Locale(identifier: "en_GB"))
      .environment(\.calendar, calendar)
      .environment(\.timeZone, calendar.timeZone)
      .task { await loadStore() }
  }

  @ViewBuilder private var content: some View {
    switch phase {
    case .loading:
      HomeView()
    case .failed:
      HomeView(message: "Nap Time could not open its data.")
    case .ready(let store):
      if store.children.isEmpty {
        ChildFormView(
          kind: .first, today: today, calendar: calendar,
          onSave: { name, birthDate, photo in
            let child = try await store.add(name: name, birthDate: birthDate, photo: photo)
            select(child.id)
            tab = .today
          })
      } else {
        // The status line, the totals, and the sky update every minute, so the sky changes within a minute
        // of its phase edge (SkyPhase.nextChange). In test mode the clock stays at `--now`.
        TimelineView(.everyMinute) { context in
          let now = fixedNow ?? context.date
          let selected = SelectedChild.id(saved: selectedID, in: store.children)
          if tab == .charts, let child = store.children.first(where: { $0.id == selected }) {
            ChartsView(
              child: child, sleeps: store.sleeps(of: child.id), now: now, timeZone: calendar.timeZone,
              onAddSleep: { cover = .sleep(.new($0, childID: child.id)) },
              onTab: { tab = $0 }
            )
            // A new child opens Charts on the opening week again.
            .id(child.id)
          } else {
            HomeView(
              children: store.children,
              selectedID: selected,
              status: selected.map { ChildStatus(sleeps: store.sleeps(of: $0), now: now, in: calendar.timeZone) },
              onSelect: select,
              onAdd: { cover = .addAnother },
              onEdit: { cover = .edit($0) },
              onSleep: { if let selected { startSleep(selected, store: store) } },
              onWake: { if let selected { endSleep(selected, store: store) } },
              onSleepLink: { if let selected { openSleepLink(selected, store: store, now: now) } },
              onStatusLine: selected.flatMap { statusLineAction($0, store: store) },
              onTab: { tab = $0 }
            )
          }
        }
        .fullScreenCover(item: $cover) { cover in
          coverView(cover, store: store)
        }
      }
    }
  }

  @ViewBuilder private func coverView(_ cover: Cover, store: FamilyStore) -> some View {
    switch cover {
    case .addAnother:
      ChildFormView(
        kind: .another, today: today, calendar: calendar,
        onSave: { name, birthDate, photo in
          let child = try await store.add(name: name, birthDate: birthDate, photo: photo)
          select(child.id)
          self.cover = nil
        },
        onCancel: { self.cover = nil })
    case .edit(let id):
      if let index = store.children.firstIndex(where: { $0.id == id }) {
        ChildFormView(
          kind: .edit(store.children[index], index: index), today: today, calendar: calendar,
          onSave: { name, birthDate, photo in
            try await store.update(id, name: name, birthDate: birthDate, newPhoto: photo)
            self.cover = nil
          },
          onCancel: { self.cover = nil },
          onDelete: {
            self.cover = nil
            do {
              try store.delete(id)
            } catch {
              Self.logger.error("Delete failed: \(String(describing: error), privacy: .public)")
            }
          })
      }
    case .sleep(let mode):
      if let child = store.children.first(where: { $0.id == mode.childID }) {
        SleepFormView(
          mode: mode, child: child, sleeps: store.sleeps(of: child.id), now: fixedNow ?? Date(), calendar: calendar,
          onSave: { sleep in
            try store.saveSleep(sleep)
            self.cover = nil
          },
          onCancel: { self.cover = nil },
          onDelete: { sleep in
            try store.deleteSleep(id: sleep.id)
            self.cover = nil
          })
      }
    }
  }

  /// "Add a sleep from earlier" while the child is awake, "Woke earlier? Set the time" while a sleep runs.
  private func openSleepLink(_ childID: Child.ID, store: FamilyStore, now: Date) {
    if let running = store.sleeps(of: childID).first(where: \.isRunning) {
      cover = .sleep(.wokeEarlier(running))
    } else {
      cover = .sleep(.new(SleepStartValues.today(now: now, in: calendar.timeZone), childID: childID))
    }
  }

  /// The status line opens the running sleep, or else the child's last sleep. With no sleeps it does nothing.
  private func statusLineAction(_ childID: Child.ID, store: FamilyStore) -> (() -> Void)? {
    guard let last = store.sleeps(of: childID).first(where: \.isRunning) ?? store.sleeps(of: childID).first else {
      return nil
    }
    return { cover = .sleep(last.isRunning ? .runningStart(last) : .edit(last)) }
  }

  /// "Sleep time": starts a running sleep now, a night or a nap by the time of day.
  private func startSleep(_ childID: Child.ID, store: FamilyStore) {
    let now = fixedNow ?? Date()
    do {
      try store.startSleep(childID: childID, at: now, kind: SleepKind.guess(start: now, in: calendar.timeZone))
    } catch {
      Self.logger.error("Sleep time failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// "Wake up": ends the running sleep now.
  private func endSleep(_ childID: Child.ID, store: FamilyStore) {
    do {
      try store.endSleep(childID: childID, at: fixedNow ?? Date())
    } catch {
      Self.logger.error("Wake up failed: \(String(describing: error), privacy: .public)")
    }
  }

  private func select(_ id: Child.ID) {
    selectedID = id
    // Test mode does not read or write user defaults, so every run starts the same.
    if mode == .normal {
      UserDefaults.standard.set(id.uuidString, forKey: Self.selectedChildKey)
    }
  }

  /// Loads the family store. In test mode it adds the children and the sleeps of the seed first.
  /// On failure, it logs the error and keeps the home screen with the sky.
  private func loadStore() async {
    do {
      let groupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: FamilyStore.appGroupIdentifier)
      let description = try FamilyStore.storeDescription(for: mode, appGroupContainerURL: groupURL)
      let fixedNow = fixedNow
      let store = try await FamilyStore.load(description, now: { fixedNow ?? Date() })
      if case .test(let environment) = mode {
        var ids: [Child.ID] = []
        for child in environment.seed.children {
          let photo = child.drawsPhoto ? SeedPhoto.pngData() : nil
          ids.append(try await store.add(name: child.name, birthDate: child.birthDate, photo: photo).id)
        }
        for sleep in environment.seed.sleeps {
          try store.startSleep(childID: ids[sleep.childIndex], at: sleep.start, kind: sleep.kind)
          if let end = sleep.end {
            try store.endSleep(childID: ids[sleep.childIndex], at: end)
          }
        }
        selectedID = environment.seed.selectedIndex.map { ids[$0] }
      } else {
        selectedID = UserDefaults.standard.string(forKey: Self.selectedChildKey).flatMap(UUID.init(uuidString:))
      }
      phase = .ready(store)
    } catch {
      Self.logger.error("The family store did not load: \(String(describing: error), privacy: .public)")
      phase = .failed
    }
  }
}

/// The photo that test mode gives a seeded child: a drawing, not a real photo.
enum SeedPhoto {
  @MainActor static func pngData() -> Data? {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let size = CGSize(width: 600, height: 600)
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor(red: 0.44, green: 0.75, blue: 1, alpha: 1).setFill()
      context.fill(CGRect(origin: .zero, size: size))
      UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1).setFill()
      context.cgContext.fillEllipse(in: CGRect(x: 360, y: 80, width: 150, height: 150))
      UIColor(red: 0.30, green: 0.68, blue: 0.36, alpha: 1).setFill()
      context.cgContext.fillEllipse(in: CGRect(x: -150, y: 380, width: 900, height: 500))
      UIColor.white.setFill()
      context.cgContext.fillEllipse(in: CGRect(x: 60, y: 140, width: 200, height: 70))
    }
    return image.pngData()
  }
}
