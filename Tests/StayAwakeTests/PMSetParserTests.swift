import Foundation
import Testing

@testable import StayAwake

struct PMSetParserTests {
    static let custom = """
        Battery Power:
         Sleep On Power Button 1
         standby              1
         powernap             1
         hibernatefile        /var/vm/sleepimage
         womp                 0
         sleep                1
         disksleep            10
        AC Power:
         Sleep On Power Button 1
         standby              1
         womp                 1
         sleep                1
         disksleep            10
        """

    @Test func parsesBothProfiles() {
        let profiles = PMSetParser.parseCustom(Self.custom)
        #expect(profiles[.battery]?["sleep"] == "1")
        #expect(profiles[.battery]?["womp"] == "0")
        #expect(profiles[.battery]?["disksleep"] == "10")
        #expect(profiles[.ac]?["womp"] == "1")
        #expect(profiles[.ac]?["hibernatefile"] == nil)
    }

    @Test func desktopMacHasOnlyACProfile() {
        let profiles = PMSetParser.parseCustom("AC Power:\n sleep 5\n")
        #expect(profiles[.battery] == nil)
        #expect(profiles[.ac]?["sleep"] == "5")
    }

    @Test func ignoresUnknownProfiles() {
        let profiles = PMSetParser.parseCustom("UPS Power:\n sleep 5\nAC Power:\n sleep 3\n")
        #expect(profiles[.ac]?["sleep"] == "3")
        #expect(profiles.count == 1)
    }

    @Test(arguments: ["", "garbage", "sudo: a password is required", "AC Power:\n sleep never\n"])
    func rejectsUnusableBackups(_ text: String) {
        #expect(!PMSetParser.isUsableBackup(PMSetParser.parseCustom(text)))
    }

    @Test func acceptsRealBackup() {
        #expect(PMSetParser.isUsableBackup(PMSetParser.parseCustom(Self.custom)))
    }
}

struct PowerStatusTests {
    static let awakeSettings = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         standby              0
         Sleep On Power Button 1
         sleep                0 (sleep prevented by powerd, caffeinate)
         disksleep            0
        """

    @Test func detectsAwakeMode() {
        let status = PowerStatus(settings: Self.awakeSettings, battery: "Now drawing from 'AC Power'")
        #expect(status.isAwake)
        #expect(status.onAC)
    }

    @Test func idleSleepAloneIsNotAwake() {
        let settings = Self.awakeSettings.replacingOccurrences(of: "SleepDisabled\t\t1", with: "SleepDisabled\t\t0")
        let status = PowerStatus(settings: settings, battery: "Now drawing from 'Battery Power'")
        #expect(!status.isAwake)
        #expect(!status.onAC)
    }

    @Test func normalSleepIsNotAwake() {
        let status = PowerStatus(settings: "Currently in use:\n sleep 1\n", battery: "")
        #expect(!status.isAwake)
    }
}

struct LaunchAgentTests {
    @Test func propertyListIsValid() throws {
        let plist = LaunchAgent.propertyList(
            executablePath: "/Applications/StayAwake.app/Contents/MacOS/StayAwake",
            bundleIdentifier: "com.nejdetkadirbektas.stayawake"
        )
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let decoded = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        #expect(decoded["Label"] as? String == LaunchAgent.label)
        #expect(decoded["RunAtLoad"] as? Bool == true)
        #expect(decoded["ProgramArguments"] as? [String] == ["/Applications/StayAwake.app/Contents/MacOS/StayAwake"])
        #expect(decoded["AssociatedBundleIdentifiers"] as? [String] == ["com.nejdetkadirbektas.stayawake"])
    }
}
