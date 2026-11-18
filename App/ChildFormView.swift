import Core
import PhotosUI
import SwiftUI
import UIKit

/// Which child form to show.
enum ChildFormKind {
  /// "Add your child" on first launch: no Cancel, with the partner hint.
  case first
  /// "Add a child" from "+", with Cancel.
  case another
  /// "Edit child", with Cancel and "Delete <name>".
  case edit(Child, index: Int)
}

/// The form to add or edit a child: a photo, a name, and a birthdate.
struct ChildFormView: View {
  let kind: ChildFormKind
  let today: BirthDate
  let calendar: Calendar
  /// The child is only on this phone, so a delete reaches only this phone.
  var onlyOnThisPhone = false
  /// Saves the trimmed name, the birthdate, and the picked image data (`nil` when no photo was picked).
  let onSave: (String, BirthDate, Data?) async throws -> Void
  var onCancel: () -> Void = {}
  var onDelete: () -> Void = {}

  @State private var name: String
  @State private var birthDate: BirthDate?
  @State private var pickedItem: PhotosPickerItem?
  @State private var pickedPhoto: Data?
  @State private var showsDatePicker = false
  @State private var draftDate = Date()
  @State private var confirmsDelete = false
  @State private var isSaving = false
  @State private var isLoadingPhoto = false
  @State private var errorText: String?
  @FocusState private var nameIsFocused: Bool

  init(
    kind: ChildFormKind, today: BirthDate, calendar: Calendar, onlyOnThisPhone: Bool = false,
    onSave: @escaping (String, BirthDate, Data?) async throws -> Void,
    onCancel: @escaping () -> Void = {}, onDelete: @escaping () -> Void = {}
  ) {
    self.kind = kind
    self.today = today
    self.calendar = calendar
    self.onlyOnThisPhone = onlyOnThisPhone
    self.onSave = onSave
    self.onCancel = onCancel
    self.onDelete = onDelete
    if case .edit(let child, _) = kind {
      _name = State(initialValue: child.name)
      _birthDate = State(initialValue: child.birthDate)
    } else {
      _name = State(initialValue: "")
      _birthDate = State(initialValue: nil)
    }
  }

  private var savedChild: Child? {
    if case .edit(let child, _) = kind { child } else { nil }
  }

  private var title: String {
    switch kind {
    case .first: "Add your child"
    case .another: "Add a child"
    case .edit: "Edit child"
    }
  }

  private var validName: String? { ChildName.validated(name) }

  private var limits: ClosedRange<BirthDate> {
    if let savedChild {
      BirthDateLimits.forEditing(saved: savedChild.birthDate, today: today)
    } else {
      BirthDateLimits.forAdding(today: today)
    }
  }

  private var primaryTitle: String {
    if savedChild != nil { return "Save" }
    if let validName, birthDate != nil { return "Add \(validName)" }
    return "Add child"
  }

  var body: some View {
    ZStack {
      Theme.daySkyMid.ignoresSafeArea()
      VStack(spacing: 12) {
        header
        photoPicker
        nameField
        birthDateField
        buttons
          .opacity(confirmsDelete ? 0 : 1)
          .accessibilityHidden(confirmsDelete)
        if case .first = kind {
          Text("Does your partner already use Nap Time? Open the invite link from your partner instead.")
            .font(.baloo(15))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(Theme.navy)
      .padding(.horizontal, 20)
      if confirmsDelete, let savedChild {
        deleteConfirmation(savedChild)
      }
    }
    .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    .onChange(of: pickedItem) { _, item in
      guard let item else { return }
      loadPhoto(item)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(savedChild == nil ? "add-child" : "edit-child")
  }

  // MARK: Parts

  private var header: some View {
    HStack(spacing: 12) {
      if case .first = kind {
        titleText
      } else {
        Button("Cancel", action: onCancel)
          .font(.baloo(19, .bold))
          .frame(minWidth: 64, alignment: .leading)
          .accessibilityIdentifier("cancel")
        titleText
        Color.clear.frame(width: 64, height: 1)
      }
    }
    .frame(minHeight: 44)
  }

  private var titleText: some View {
    Text(title)
      .font(.baloo(30, .extraBold))
      .frame(maxWidth: .infinity)
      .multilineTextAlignment(.center)
  }

  private var photoPicker: some View {
    PhotosPicker(selection: $pickedItem, matching: .images) {
      VStack(spacing: 4) {
        photoCircle
          .frame(width: 120, height: 120)
        Text(savedChild == nil && pickedPhoto == nil ? "Add a photo (optional)" : "Change photo")
          .font(.baloo(16))
      }
      .foregroundStyle(Theme.navy)
    }
    .accessibilityLabel(savedChild == nil && pickedPhoto == nil ? "Add a photo" : "Change the photo")
  }

  @ViewBuilder private var photoCircle: some View {
    if let pickedPhoto, let image = UIImage(data: pickedPhoto) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 6))
    } else if case .edit(let child, let index) = kind {
      ChildPicture(child: child, index: index, letterSize: 52)
        .overlay(Circle().strokeBorder(.white, lineWidth: 6))
    } else {
      ZStack {
        Circle().fill(.white)
        Circle().strokeBorder(Theme.navy, style: StrokeStyle(lineWidth: 3, dash: [7, 4]))
        Image(systemName: "camera")
          .font(.system(size: 36, weight: .semibold))
      }
    }
  }

  private var nameField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Name")
        .font(.baloo(16, .bold))
        .padding(.leading, 6)
      TextField("Name", text: $name, prompt: Text("Your child's name").foregroundStyle(Theme.handle))
        .font(.baloo(22, .bold))
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .focused($nameIsFocused)
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("name")
    }
  }

  private var birthDateField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Birthdate")
        .font(.baloo(16, .bold))
        .padding(.leading, 6)
      Button {
        nameIsFocused = false
        draftDate = clampedDraft()
        showsDatePicker = true
      } label: {
        HStack {
          Text(birthDate?.description ?? "Choose a date")
            .foregroundStyle(birthDate == nil ? Theme.handle : Theme.navy)
          Spacer(minLength: 8)
          Image(systemName: "chevron.right")
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(Theme.navy)
        }
        .font(.baloo(22, .bold))
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
      }
      .accessibilityIdentifier("birthdate")
      if let birthDate {
        Text(ChildHint.text(name: validName ?? "Your child", birthDate: birthDate, today: today))
          .font(.baloo(14))
          .padding(.leading, 6)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let errorText {
        Text(errorText)
          .font(.baloo(14, .bold))
          .foregroundStyle(Theme.tooLittle)
          .padding(.leading, 6)
      }
    }
  }

  private var buttons: some View {
    VStack(spacing: 12) {
      Button(primaryTitle) { save() }
        .buttonStyle(PrimaryButtonStyle())
        // Wait for a picked photo, so Save never drops it.
        .disabled(validName == nil || birthDate == nil || isSaving || isLoadingPhoto)
        .accessibilityIdentifier("save")
      if let savedChild {
        Button("Delete \(savedChild.name)") { confirmsDelete = true }
          .font(.baloo(19, .bold))
          .foregroundStyle(Theme.tooLittle)
          .multilineTextAlignment(.center)
          .padding(8)
          .accessibilityIdentifier("delete")
      }
    }
  }

  private var datePickerSheet: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button("Done") {
          birthDate = BirthDate(draftDate, in: calendar)
          showsDatePicker = false
        }
        .font(.baloo(19, .bold))
        .foregroundStyle(Theme.navy)
      }
      DatePicker(
        "Birthdate", selection: $draftDate,
        in: limits.lowerBound.date(in: calendar)...limits.upperBound.date(in: calendar),
        displayedComponents: .date
      )
      .datePickerStyle(.wheel)
      .labelsHidden()
    }
    .padding(20)
    .environment(\.calendar, calendar)
    .environment(\.timeZone, calendar.timeZone)
    .environment(\.locale, calendar.locale ?? Locale(identifier: "en_GB"))
    .presentationDetents([.height(320)])
  }

  private func deleteConfirmation(_ child: Child) -> some View {
    ZStack(alignment: .bottom) {
      Theme.scrim.ignoresSafeArea()
      VStack(spacing: 10) {
        Text("Delete \(child.name)?")
          .font(.baloo(26, .extraBold))
          .accessibilityAddTraits(.isHeader)
        Text(DeleteText.child(name: child.name, onlyOnThisPhone: onlyOnThisPhone))
          .font(.baloo(17))
        Button("Delete \(child.name)", action: onDelete)
          .buttonStyle(PrimaryButtonStyle(destructive: true))
          .padding(.top, 6)
          .accessibilityIdentifier("confirm-delete")
        Button("Cancel") { confirmsDelete = false }
          .font(.baloo(19, .bold))
          .padding(8)
          .accessibilityIdentifier("confirm-cancel")
      }
      .foregroundStyle(Theme.navy)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(EdgeInsets(top: 22, leading: 20, bottom: 16, trailing: 20))
      .background(.white, in: RoundedRectangle(cornerRadius: 30))
      .padding(.horizontal, 12)
    }
  }

  // MARK: Actions

  /// The date the wheel opens on: the chosen birthdate, or today, inside the limits.
  private func clampedDraft() -> Date {
    let day = birthDate ?? today
    let clamped = min(max(day, limits.lowerBound), limits.upperBound)
    return clamped.date(in: calendar)
  }

  /// Loads the picked photo. Save stays disabled until the load ends.
  private func loadPhoto(_ item: PhotosPickerItem) {
    isLoadingPhoto = true
    errorText = nil
    Task {
      do {
        guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadUnknown) }
        pickedPhoto = data
      } catch {
        errorText = "Nap Time could not load this photo. Try another one."
      }
      isLoadingPhoto = false
    }
  }

  private func save() {
    guard let validName, let birthDate else { return }
    isSaving = true
    errorText = nil
    Task {
      do {
        try await onSave(validName, birthDate, pickedPhoto)
      } catch {
        errorText = "Nap Time could not save this. Try again."
      }
      isSaving = false
    }
  }
}
