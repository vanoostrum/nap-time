import Core
import Foundation
import Testing

@Suite struct FamilySharingTests {
  private func share(
    ownedByMe: Bool = true, owner: String? = "Alex", participants: [ShareFacts.Participant] = []
  ) -> ShareFacts.Share {
    ShareFacts.Share(isOwnedByMe: ownedByMe, ownerGivenName: owner, participants: participants)
  }

  @Test func noICloudAccountGivesNoICloud() {
    let facts = ShareFacts(
      hasICloudAccount: false, share: share(participants: [.init(accepted: true, givenName: "Sam")]))
    #expect(FamilySharing(facts) == .noICloud)
  }

  @Test func noShareGivesNotShared() {
    #expect(FamilySharing(ShareFacts(hasICloudAccount: true, share: nil)) == .notShared)
  }

  @Test func aShareWithOnlyTheOwnerGivesNotShared() {
    #expect(FamilySharing(ShareFacts(hasICloudAccount: true, share: share())) == .notShared)
  }

  @Test func onlyPendingParticipantsGiveInvited() {
    let facts = ShareFacts(
      hasICloudAccount: true, share: share(participants: [.init(accepted: false, givenName: "Sam")]))
    #expect(FamilySharing(facts) == .invited)
  }

  @Test func anAcceptedParticipantGivesSharedWithTheGivenName() {
    let facts = ShareFacts(
      hasICloudAccount: true,
      share: share(participants: [.init(accepted: false, givenName: "Kim"), .init(accepted: true, givenName: "Sam")]))
    #expect(FamilySharing(facts) == .shared(partner: "Sam"))
  }

  @Test func anAcceptedParticipantWithoutAGivenNameIsYourPartner() {
    let facts = ShareFacts(hasICloudAccount: true, share: share(participants: [.init(accepted: true, givenName: nil)]))
    #expect(FamilySharing(facts) == .shared(partner: "your partner"))
  }

  @Test func aShareOwnedBySomeoneElseGivesJoined() {
    let facts = ShareFacts(hasICloudAccount: true, share: share(ownedByMe: false, owner: "Alex"))
    #expect(FamilySharing(facts) == .joined(owner: "Alex"))
    let noName = ShareFacts(hasICloudAccount: true, share: share(ownedByMe: false, owner: nil))
    #expect(FamilySharing(noName) == .joined(owner: "your partner"))
  }

  @Test func theSettingsTextsOfEachState() {
    #expect(FamilySharing.notShared.settingsTitle == "Not shared yet")
    #expect(FamilySharing.notShared.settingsText == "Your partner sees and logs the same children and sleeps.")
    #expect(FamilySharing.notShared.settingsButton == .invite)
    #expect(FamilySharing.notShared.settingsButton?.title == "Invite your partner")

    #expect(FamilySharing.invited.settingsTitle == "Invite sent")
    #expect(FamilySharing.invited.settingsText == "Waiting for your partner to open the link.")
    #expect(FamilySharing.invited.settingsButton == .manage)
    #expect(FamilySharing.invited.settingsButton?.title == "Manage sharing")

    #expect(FamilySharing.shared(partner: "Sam").settingsTitle == "Shared with Sam")
    #expect(
      FamilySharing.shared(partner: "Sam").settingsText == "You both see and log the same children and sleeps.")
    #expect(FamilySharing.shared(partner: "Sam").settingsButton == .manage)
    #expect(FamilySharing.shared(partner: "your partner").settingsTitle == "Shared with your partner")

    #expect(FamilySharing.joined(owner: "Alex").settingsTitle == "Shared with you by Alex")
    #expect(
      FamilySharing.joined(owner: "Alex").settingsText == "You both see and log the same children and sleeps.")
    #expect(FamilySharing.joined(owner: "Alex").settingsButton == .manage)
    #expect(FamilySharing.joined(owner: "your partner").settingsTitle == "Shared with you by your partner")

    #expect(FamilySharing.noICloud.settingsTitle == "Not shared yet")
    #expect(
      FamilySharing.noICloud.settingsText == "Sign in to iCloud in the iPhone Settings to share with your partner.")
    #expect(FamilySharing.noICloud.settingsButton == nil)
  }

  @Test func theInviteRuleIgnoresTheOwnLink() {
    for sharing in [FamilySharing.notShared, .invited, .shared(partner: "Sam"), .noICloud] {
      #expect(InviteRule.decision(isOwnLink: true, sharing: sharing) == .ignore)
    }
  }

  @Test func theInviteRuleRefusesAPhoneInAFamily() {
    for sharing in [FamilySharing.joined(owner: "Alex"), .shared(partner: "Sam"), .invited] {
      #expect(InviteRule.decision(isOwnLink: false, sharing: sharing) == .refuse)
    }
    #expect(InviteRule.refusalTitle == "You are already in a family")
    #expect(
      InviteRule.refusalText
        == "Nap Time holds one family per phone. Leave or stop sharing in Settings, under Manage sharing, first.")
  }

  @Test func theInviteRuleAcceptsOtherwise() {
    #expect(InviteRule.decision(isOwnLink: false, sharing: .notShared) == .accept)
    #expect(InviteRule.decision(isOwnLink: false, sharing: .noICloud) == .accept)
  }
}

@Suite struct FamilyTextTests {
  private let today = BirthDate(year: 2026, month: 6, day: 21)!

  @Test func theRowTextGivesTheAgeAndTheRange() {
    #expect(ChildRow.text(birthDate: BirthDate(year: 2025, month: 3, day: 12)!, today: today) == "1 year · 11–14 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2022, month: 2, day: 10)!, today: today) == "4 years · 10–13 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2024, month: 5, day: 3)!, today: today) == "2 years · 11–14 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2026, month: 6, day: 20)!, today: today) == "1 day · 14–17 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2026, month: 6, day: 16)!, today: today) == "5 days · 14–17 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2026, month: 6, day: 14)!, today: today) == "1 week · 14–17 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2026, month: 5, day: 21)!, today: today) == "1 month · 14–17 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2026, month: 1, day: 10)!, today: today) == "5 months · 12–16 h")
  }

  @Test func theRangeChangesOnTheBirthday() {
    // Lou turns 3 on 21 June 2026: the range moves from 11–14 h to 10–13 h on that day.
    #expect(ChildRow.text(birthDate: BirthDate(year: 2023, month: 6, day: 22)!, today: today) == "2 years · 11–14 h")
    #expect(ChildRow.text(birthDate: BirthDate(year: 2023, month: 6, day: 21)!, today: today) == "3 years · 10–13 h")
  }

  @Test func theJoinedTextNamesTheSharedChildren() {
    #expect(JoinedText.text(names: ["Mila"]) == "You now see and log Mila, together with your partner.")
    #expect(
      JoinedText.text(names: ["Mila", "Noah"]) == "You now see and log Mila and Noah, together with your partner.")
    #expect(
      JoinedText.text(names: ["Mila", "Noah", "Lou"])
        == "You now see and log Mila, Noah, and Lou, together with your partner.")
    #expect(JoinedText.title == "You joined the family")
  }

  @Test func theChildDeleteTexts() {
    #expect(
      DeleteText.child(name: "Mila", onlyOnThisPhone: false)
        == "This deletes Mila and all of Mila's sleeps, on both phones. You cannot undo this.")
    #expect(
      DeleteText.child(name: "Lou", onlyOnThisPhone: true)
        == "This deletes Lou and all of Lou's sleeps, on this phone. You cannot undo this.")
  }

  @Test func theSleepDeleteTexts() {
    let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
    let night = Sleep(
      id: UUID(), childID: UUID(), start: date("2026-06-20T19:45:00+02:00"), end: date("2026-06-21T06:55:00+02:00"),
      kind: .night)
    #expect(
      DeleteText.sleep(night, name: "Mila", onlyOnThisPhone: false, now: night.end!, in: amsterdam)
        == "This deletes Mila's night from 19:45 to 06:55, on both phones. You cannot undo this.")
    let nap = Sleep(
      id: UUID(), childID: UUID(), start: date("2026-06-21T13:00:00+02:00"), end: date("2026-06-21T14:00:00+02:00"),
      kind: .nap)
    #expect(
      DeleteText.sleep(nap, name: "Lou", onlyOnThisPhone: true, now: nap.end!, in: amsterdam)
        == "This deletes Lou's nap from 13:00 to 14:00, on this phone. You cannot undo this.")
    let running = Sleep(id: UUID(), childID: UUID(), start: nap.start, end: nil, kind: .nap)
    #expect(
      DeleteText.sleep(
        running, name: "Lou", onlyOnThisPhone: true, now: date("2026-06-21T13:30:00+02:00"), in: amsterdam)
        == "This deletes Lou's nap from 13:00 to 13:30, on this phone. You cannot undo this.")
  }
}

@Suite struct JoinScreenTests {
  @Test func noAcceptRunningAndNoPendingJoinGivesNoJoinScreen() {
    #expect(JoinScreen(acceptRunning: false, pendingJoin: false, sharedChildCount: 0) == nil)
    #expect(JoinScreen(acceptRunning: false, pendingJoin: false, sharedChildCount: 2) == nil)
  }

  @Test func acceptRunningGivesJoining() {
    #expect(JoinScreen(acceptRunning: true, pendingJoin: false, sharedChildCount: 0) == .joining)
    #expect(JoinScreen(acceptRunning: true, pendingJoin: true, sharedChildCount: 0) == .joining)
    #expect(JoinScreen(acceptRunning: true, pendingJoin: true, sharedChildCount: 2) == .joining)
  }

  @Test func aPendingJoinWithNoSharedChildGivesJoining() {
    // A child only on this phone is not in the shared store, so the count is 0.
    #expect(JoinScreen(acceptRunning: false, pendingJoin: true, sharedChildCount: 0) == .joining)
    #expect(JoinScreen.joining.title == "Joining the family…")
    #expect(JoinScreen.joiningText == "This takes a few seconds.")
  }

  @Test func aPendingJoinWithASharedChildGivesJoined() {
    #expect(JoinScreen(acceptRunning: false, pendingJoin: true, sharedChildCount: 1) == .joined)
    #expect(JoinScreen.joined.title == "You joined the family")
  }
}

@Suite struct SleepMergeTests {
  private let mila = UUID()
  private let noah = UUID()

  private func sleep(_ start: String, _ end: String?, _ kind: SleepKind = .night, child: UUID? = nil, id: UUID = UUID())
    -> Sleep
  {
    Sleep(id: id, childID: child ?? mila, start: date(start), end: end.map(date), kind: kind)
  }

  @Test func sleepsThatDoNotOverlapAreKept() {
    let sleeps = [
      sleep("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00"),
      sleep("2026-06-21T13:00:00+02:00", "2026-06-21T14:00:00+02:00", .nap),
    ]
    #expect(SleepMerge.merges(of: sleeps).isEmpty)
  }

  @Test func sleepsThatOnlyTouchAreKept() {
    let sleeps = [
      sleep("2026-06-21T13:00:00+02:00", "2026-06-21T14:00:00+02:00", .nap),
      sleep("2026-06-21T14:00:00+02:00", "2026-06-21T15:00:00+02:00", .nap),
    ]
    #expect(SleepMerge.merges(of: sleeps).isEmpty)
  }

  @Test func twoRunningSleepsKeepTheEarlierStartAndRun() {
    let first = sleep("2026-06-21T19:42:00+02:00", nil)
    let second = sleep("2026-06-21T19:44:00+02:00", nil)
    let merges = SleepMerge.merges(of: [second, first])
    #expect(merges == [SleepMerge.Merge(kept: first, deleted: [second.id])])
  }

  @Test func twoRunningSleepsWithEqualStartsKeepTheLowestID() {
    let low = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let high = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let a = sleep("2026-06-21T19:42:00+02:00", nil, id: high)
    let b = sleep("2026-06-21T19:42:00+02:00", nil, .nap, id: low)
    #expect(SleepMerge.merges(of: [a, b]) == [SleepMerge.Merge(kept: b, deleted: [high])])
    #expect(SleepMerge.merges(of: [b, a]) == [SleepMerge.Merge(kept: b, deleted: [high])])
  }

  @Test func anEndedAndARunningSleepMergeIntoTheEndedOne() {
    let running = sleep("2026-06-21T19:42:00+02:00", nil)
    let ended = sleep("2026-06-21T19:44:00+02:00", "2026-06-22T06:50:00+02:00")
    let merges = SleepMerge.merges(of: [running, ended])
    var kept = running
    kept.end = date("2026-06-22T06:50:00+02:00")
    #expect(merges == [SleepMerge.Merge(kept: kept, deleted: [ended.id])])
  }

  @Test func twoEndedSleepsTakeTheLaterEnd() {
    let first = sleep("2026-06-21T13:00:00+02:00", "2026-06-21T14:00:00+02:00", .nap)
    let second = sleep("2026-06-21T13:30:00+02:00", "2026-06-21T15:00:00+02:00", .nap)
    var kept = first
    kept.end = second.end
    #expect(SleepMerge.merges(of: [first, second]) == [SleepMerge.Merge(kept: kept, deleted: [second.id])])
  }

  @Test func aMergedSleepCanBeLongerThan24Hours() {
    let night = sleep("2026-06-20T19:00:00+02:00", "2026-06-21T08:00:00+02:00", child: noah)
    let nap = sleep("2026-06-21T07:00:00+02:00", "2026-06-21T20:30:00+02:00", .nap, child: noah)
    let merges = SleepMerge.merges(of: [nap, night])
    #expect(merges.count == 1)
    #expect(merges[0].kept.id == night.id)
    #expect(merges[0].kept.kind == .night)
    #expect(merges[0].kept.start == date("2026-06-20T19:00:00+02:00"))
    #expect(merges[0].kept.end == date("2026-06-21T20:30:00+02:00"))
    #expect(merges[0].kept.end!.timeIntervalSince(merges[0].kept.start) == 25.5 * 3600)
    #expect(merges[0].deleted == [nap.id])
  }

  @Test func aChainOfThreeSleepsIsOneGroup() {
    let a = sleep("2026-06-21T12:00:00+02:00", "2026-06-21T13:00:00+02:00", .nap)
    let b = sleep("2026-06-21T12:30:00+02:00", "2026-06-21T14:00:00+02:00", .nap)
    let c = sleep("2026-06-21T13:30:00+02:00", "2026-06-21T15:00:00+02:00", .nap)
    let merges = SleepMerge.merges(of: [c, a, b])
    var kept = a
    kept.end = c.end
    #expect(merges == [SleepMerge.Merge(kept: kept, deleted: [b.id, c.id])])
  }

  @Test func aRunningSleepOverlapsEverySleepAfterItsStart() {
    let running = sleep("2026-06-21T12:00:00+02:00", nil, .nap)
    let later = sleep("2026-06-21T18:00:00+02:00", "2026-06-21T19:00:00+02:00", .nap)
    var kept = running
    kept.end = later.end
    #expect(SleepMerge.merges(of: [running, later]) == [SleepMerge.Merge(kept: kept, deleted: [later.id])])
  }

  @Test func twoChildrenWithOneRunningSleepEachAreKept() {
    let sleeps = [
      sleep("2026-06-21T19:42:00+02:00", nil, child: mila),
      sleep("2026-06-21T19:44:00+02:00", nil, child: noah),
    ]
    #expect(SleepMerge.merges(of: sleeps).isEmpty)
  }
}
