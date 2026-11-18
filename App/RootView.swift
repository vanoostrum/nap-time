import CloudKit
import Core
import NapTimeStore
import OSLog
import SwiftUI
import UIKit

/// Loads the family store, then shows "Add your child" when there is no child, or the home screen
/// and the Charts screen with their tab bar.
struct RootView: View {
  let mode: AppMode

  @State private var cover: Cover?
  /// The app is accepting the share of an opened invite.
  @State private var acceptRunning = false
  @State private var inviteAlert: InviteAlert?

  private enum Cover: Identifiable {
    case settings
    case addAnother
    case edit(Child.ID)
    case sleep(SleepFormMode)

    var id: String {
      switch self {
      case .settings: "settings"
      case .addAnother: "add-another"
      case .edit(let id): id.uuidString
      case .sleep(.new(_, let childID)): "new-sleep-\(childID.uuidString)"
      case .sleep(.edit(let sleep)): "edit-sleep-\(sleep.id.uuidString)"
      case .sleep(.wokeEarlier(let sleep)): "woke-earlier-\(sleep.id.uuidString)"
      case .sleep(.runningStart(let sleep)): "running-start-\(sleep.id.uuidString)"
      }
    }
  }

  /// The alerts of an opened invite.
  private enum InviteAlert: Identifiable {
    case refused
    case failedJoin

    var id: Self { self }

    var title: String {
      switch self {
      case .refused: InviteRule.refusalTitle
      case .failedJoin: InviteRule.failedJoinTitle
      }
    }

    var message: String {
      switch self {
      case .refused: InviteRule.refusalText
      case .failedJoin: InviteRule.failedJoinText
      }
    }
  }

  private var invites: OpenedInvites { .shared }
  /// The owner of the store, the selected child, the tab, and the pending join, created at launch.
  private var model: AppModel { .shared }

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "FamilyStore")

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
      .task {
        // The app loads the store at launch. Handle an invite that was opened before it loaded.
        _ = await model.loadedStore()
        handleInvite()
      }
      .onChange(of: invites.metadata) { handleInvite() }
      .alert(item: $inviteAlert) { alert in
        Alert(title: Text(alert.title), message: Text(alert.message))
      }
  }

  @ViewBuilder private var content: some View {
    switch model.phase {
    case .loading:
      HomeView()
    case .failed:
      HomeView(message: "Nap Time could not open its data.")
    case .ready(let store):
      if let screen = JoinScreen(
        acceptRunning: acceptRunning, pendingJoin: model.pendingJoin, sharedChildCount: store.sharedStoreChildren.count)
      {
        JoinView(
          screen: screen, children: store.sharedStoreChildren, animates: mode == .normal,
          onStart: {
            model.pendingJoin = false
            if let first = store.sharedStoreChildren.first { model.select(first.id) }
            model.tab = .today
          })
      } else if store.children.isEmpty {
        ChildFormView(
          kind: .first, today: today, calendar: calendar,
          onSave: { name, birthDate, photo in
            let child = try await store.add(name: name, birthDate: birthDate, photo: photo)
            model.select(child.id)
            model.tab = .today
          })
      } else {
        // The status line, the totals, and the sky update every minute, so the sky changes within a minute
        // of its phase edge (SkyPhase.nextChange). In test mode the clock stays at `--now`.
        TimelineView(.everyMinute) { context in
          let now = fixedNow ?? context.date
          let selected = SelectedChild.id(saved: model.selectedID, in: store.children)
          if model.tab == .charts, let child = store.children.first(where: { $0.id == selected }) {
            ChartsView(
              child: child, sleeps: store.sleeps(of: child.id), now: now, timeZone: calendar.timeZone,
              onAddSleep: { cover = .sleep(.new($0, childID: child.id)) },
              onEditSleep: { cover = .sleep($0.isRunning ? .runningStart($0) : .edit($0)) },
              onTab: { model.tab = $0 }
            )
            // A new child opens Charts on the opening week again.
            .id(child.id)
          } else {
            HomeView(
              children: store.children,
              selectedID: selected,
              status: selected.map { ChildStatus(sleeps: store.sleeps(of: $0), now: now, in: calendar.timeZone) },
              onSelect: { model.select($0) },
              onAdd: { cover = .addAnother },
              onEdit: { cover = .edit($0) },
              onSleep: { if let selected { startSleep(selected, store: store) } },
              onWake: { if let selected { endSleep(selected, store: store) } },
              onSleepLink: { if let selected { openSleepLink(selected, store: store, now: now) } },
              onStatusLine: selected.flatMap { statusLineAction($0, store: store) },
              onTab: { model.tab = $0 },
              onSettings: { cover = .settings }
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
    case .settings:
      SettingsView(
        store: store, today: today, calendar: calendar,
        onAdded: { model.select($0) },
        onDone: { self.cover = nil })
    case .addAnother:
      ChildFormView(
        kind: .another, today: today, calendar: calendar,
        onSave: { name, birthDate, photo in
          let child = try await store.add(name: name, birthDate: birthDate, photo: photo)
          model.select(child.id)
          self.cover = nil
        },
        onCancel: { self.cover = nil })
    case .edit(let id):
      if let index = store.children.firstIndex(where: { $0.id == id }) {
        ChildFormView(
          kind: .edit(store.children[index], index: index), today: today, calendar: calendar,
          onlyOnThisPhone: store.onlyOnThisPhone.contains(id),
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
          onlyOnThisPhone: store.onlyOnThisPhone.contains(child.id),
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

  /// "Sleep time": starts a running sleep now, a night or a nap by the time of day, and requests its sleep timer.
  private func startSleep(_ childID: Child.ID, store: FamilyStore) {
    let now = fixedNow ?? Date()
    do {
      try store.startSleep(childID: childID, at: now, kind: SleepKind.guess(start: now, in: calendar.timeZone))
      model.sleepTimers?.requestTimer(for: childID)
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

  /// Handles an opened invite once the store has loaded: ignores the owner's own link, refuses an invite on a
  /// phone in a family, or joins the family. The pending join is set only after the accept succeeds.
  private func handleInvite() {
    guard case .ready(let store) = model.phase, let metadata = invites.metadata else { return }
    invites.metadata = nil
    switch InviteRule.decision(isOwnLink: metadata.participantRole == .owner, sharing: store.sharing) {
    case .ignore:
      return
    case .refuse:
      inviteAlert = .refused
    case .accept:
      acceptRunning = true
      Task {
        do {
          try await store.acceptShare(metadata)
          model.pendingJoin = true
        } catch {
          Self.logger.error("Joining the family failed: \(String(describing: error), privacy: .public)")
          model.pendingJoin = false
          inviteAlert = .failedJoin
        }
        acceptRunning = false
      }
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
