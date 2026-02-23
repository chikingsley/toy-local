import IOKit.pwr_mgt

/// Live implementation of SleepManagementClient that manages assertion lifecycle.
public actor SleepManagementClientLive: SleepManagementClient {
  private var currentAssertionID: IOPMAssertionID?

  public init() {}

  public func preventSleep(reason: String) {
    // Release any existing assertion first
    if let existingID = currentAssertionID {
      IOPMAssertionRelease(existingID)
      currentAssertionID = nil
    }

    // Create new assertion
    let reasonForActivity = reason as CFString
    var assertionID: IOPMAssertionID = 0
    let success = IOPMAssertionCreateWithName(
      kIOPMAssertionTypeNoDisplaySleep as CFString,
      IOPMAssertionLevel(kIOPMAssertionLevelOn),
      reasonForActivity,
      &assertionID
    )

    if success == kIOReturnSuccess {
      currentAssertionID = assertionID
    }
  }

  public func allowSleep() {
    if let assertionID = currentAssertionID {
      IOPMAssertionRelease(assertionID)
      currentAssertionID = nil
    }
  }
}
