import Core
import NapTimeStore
import OSLog
import SwiftUI

/// Settings, from the gear on the home screen: the children, and sharing the family with the partner
/// (`design/pages/settings/*.html`).
struct SettingsView: View {
  let store: FamilyStore
  let today: BirthDate
  let calendar: Calendar
  /// A child was added from Settings: the home screen shows it.
  let onAdded: (Child.ID) -> Void
  let onDone: () -> Void

  @State private var cover: Cover?
  @State private var failedButton: SettingsShareButton?
  @State private var opensSharing = false

  private enum Cover: Identifiable {
    case add
    case edit(Child.ID)

    var id: String {
      switch self {
      case .add: "add"
      case .edit(let id): id.uuidString
      }
    }
  }

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "Settings")

  var body: some View {
    ZStack {
      Theme.daySkyMid.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          header
          sectionTitle("Children")
          childList
          sectionTitle("Share with your partner")
          shareCard
          if let button = store.sharing.settingsButton {
            Button(button.title) { openSharing(button) }
              .buttonStyle(PrimaryButtonStyle())
              .disabled(opensSharing)
              .accessibilityIdentifier("share-button")
          }
        }
        .foregroundStyle(Theme.navy)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .fullScreenCover(item: $cover) { cover in
      coverView(cover)
    }
    .alert(
      failedButton?.failureTitle ?? "",
      isPresented: Binding(get: { failedButton != nil }, set: { _ in failedButton = nil })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(SettingsShareButton.failureText)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("settings")
  }

  // MARK: Parts

  private var header: some View {
    HStack(spacing: 12) {
      Color.clear.frame(width: 64, height: 1)
      Text("Settings")
        .balooLine(30, .extraBold, lineHeight: 32)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
      Button("Done", action: onDone)
        .font(.baloo(19, .bold))
        .frame(minWidth: 64, alignment: .trailing)
        .accessibilityIdentifier("done")
    }
    .frame(minHeight: 44)
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .balooLine(18, .extraBold, lineHeight: 19)
      .padding(.leading, 6)
      .accessibilityAddTraits(.isHeader)
  }

  private var childList: some View {
    VStack(spacing: 0) {
      ForEach(Array(store.children.enumerated()), id: \.element.id) { index, child in
        if index > 0 { divider }
        childRow(child, index: index)
      }
      if !store.children.isEmpty { divider }
      Button {
        cover = .add
      } label: {
        HStack(spacing: 12) {
          Text("+")
            .font(.baloo(26, .bold))
            .frame(width: 40, height: 40)
            .overlay(Circle().strokeBorder(Theme.navy, style: StrokeStyle(lineWidth: 3, dash: [7, 4])))
          Text("Add a child")
            .balooLine(16, lineHeight: 18)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Add a child")
      .accessibilityIdentifier("settings-add-child")
    }
    .background(RoundedRectangle(cornerRadius: 24).fill(.white))
  }

  private var divider: some View {
    Theme.track.frame(height: 2)
  }

  private func childRow(_ child: Child, index: Int) -> some View {
    let only = store.onlyOnThisPhone.contains(child.id)
    let rowText = ChildRow.text(birthDate: child.birthDate, today: today)
    return Button {
      cover = .edit(child.id)
    } label: {
      HStack(spacing: 12) {
        ChildPicture(child: child, index: index, letterSize: 18)
          .frame(width: 40, height: 40)
        VStack(alignment: .leading, spacing: 0) {
          Text(child.name)
            .balooLine(16, lineHeight: 18)
          Text(rowText)
            .balooLine(15, lineHeight: 17)
          if only {
            Text("Only on this phone")
              .balooLine(13, .bold, lineHeight: 15)
              .foregroundStyle(Theme.tagInk)
              .padding(.horizontal, 10)
              .padding(.vertical, 1)
              .background(Capsule().fill(Theme.track))
              .padding(.top, 4)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .font(.system(size: 15, weight: .heavy))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(minHeight: 64)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(child.name)
    .accessibilityValue(only ? "\(rowText), Only on this phone" : rowText)
    .accessibilityIdentifier("child-row")
  }

  private var shareCard: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(store.sharing.settingsTitle)
        .balooLine(21, .bold, lineHeight: 25)
        .accessibilityIdentifier("share-title")
      Text(store.sharing.settingsText)
        .balooLine(15, lineHeight: 17)
        .opacity(0.8)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("share-text")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 24).fill(.white))
  }

  @ViewBuilder private func coverView(_ cover: Cover) -> some View {
    switch cover {
    case .add:
      ChildFormView(
        kind: .another, today: today, calendar: calendar,
        onSave: { name, birthDate, photo in
          let child = try await store.add(name: name, birthDate: birthDate, photo: photo)
          onAdded(child.id)
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
            // Deleting the last child closes Settings, and the app opens "Add your child".
            if store.children.count == 1 { onDone() }
            do {
              try store.delete(id)
            } catch {
              Self.logger.error("Delete failed: \(String(describing: error), privacy: .public)")
            }
          })
      }
    }
  }

  // MARK: Actions

  /// "Invite your partner" or "Manage sharing": opens the iCloud sharing sheet for the family share.
  private func openSharing(_ button: SettingsShareButton) {
    opensSharing = true
    Task {
      do {
        let share = try await store.share()
        CloudSharing.shared.present(share, store: store)
      } catch {
        Self.logger.error("Sharing failed: \(String(describing: error), privacy: .public)")
        failedButton = button
      }
      opensSharing = false
    }
  }
}
