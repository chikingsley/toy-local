import AppKit
import Foundation
import ToyLocalCore

private let mediaLogger = ToyLocalLog.media

typealias MRNowPlayingIsPlayingFunc = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias MRMediaRemoteSendCommandFunc = @convention(c) (Int32, CFDictionary?) -> Void

enum MediaRemoteCommand: Int32 {
	case play = 0
	case pause = 1
	case togglePlayPause = 2
}

@Observable
class MediaRemoteController {
	private var mediaRemoteHandle: UnsafeMutableRawPointer?
	private var mrNowPlayingIsPlaying: MRNowPlayingIsPlayingFunc?
	private var mrSendCommand: MRMediaRemoteSendCommandFunc?

	init?() {
		guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) as UnsafeMutableRawPointer? else {
			mediaLogger.error("Unable to open MediaRemote framework")
			return nil
		}
		mediaRemoteHandle = handle

		guard let playingPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
			mediaLogger.error("Unable to find MRMediaRemoteGetNowPlayingApplicationIsPlaying symbol")
			return nil
		}
		mrNowPlayingIsPlaying = unsafeBitCast(playingPtr, to: MRNowPlayingIsPlayingFunc.self)

		if let commandPtr = dlsym(handle, "MRMediaRemoteSendCommand") {
			mrSendCommand = unsafeBitCast(commandPtr, to: MRMediaRemoteSendCommandFunc.self)
		} else {
			mediaLogger.error("Unable to find MRMediaRemoteSendCommand symbol")
		}
	}

	deinit {
		if let handle = mediaRemoteHandle {
			dlclose(handle)
		}
	}

	func isMediaPlaying() async -> Bool {
		guard let isPlayingFunc = mrNowPlayingIsPlaying else { return false }
		return await withCheckedContinuation { continuation in
			isPlayingFunc(DispatchQueue.main) { isPlaying in
				continuation.resume(returning: isPlaying)
			}
		}
	}

	func send(_ command: MediaRemoteCommand) -> Bool {
		guard let sendCommand = mrSendCommand else {
			return false
		}
		sendCommand(command.rawValue, nil)
		return true
	}
}

nonisolated(unsafe) let mediaRemoteController = MediaRemoteController()

func isAudioPlayingOnDefaultOutput() async -> Bool {
	return await mediaRemoteController?.isMediaPlaying() ?? false
}

private func isAppInstalled(bundleID: String) -> Bool {
	let workspace = NSWorkspace.shared
	return workspace.urlForApplication(withBundleIdentifier: bundleID) != nil
}

private let installedMediaPlayers: [String: String] = {
	var result: [String: String] = [:]

	if isAppInstalled(bundleID: "com.apple.Music") {
		result["Music"] = "com.apple.Music"
	}

	if isAppInstalled(bundleID: "com.apple.iTunes") {
		result["iTunes"] = "com.apple.iTunes"
	}

	if isAppInstalled(bundleID: "com.spotify.client") {
		result["Spotify"] = "com.spotify.client"
	}

	if isAppInstalled(bundleID: "org.videolan.vlc") {
		result["VLC"] = "org.videolan.vlc"
	}

	return result
}()

private nonisolated(unsafe) var mediaControlErrorCount = 0
private nonisolated(unsafe) var mediaControlDisabled = false

func pauseAllMediaApplications() -> [String] {
	if mediaControlDisabled { return [] }
	if installedMediaPlayers.isEmpty {
		return []
	}

	mediaLogger.debug("Installed media players: \(installedMediaPlayers.keys.joined(separator: ", "))")

	var scriptParts: [String] = ["set pausedPlayers to {}"]

	for (appName, _) in installedMediaPlayers {
		if appName == "VLC" {
			scriptParts.append("""
			try
				if application "VLC" is running then
					tell application "VLC"
						if playing then
							pause
							set end of pausedPlayers to "VLC"
						end if
					end tell
				end if
			end try
			""")
		} else {
			scriptParts.append("""
			try
				if application "\(appName)" is running then
					tell application "\(appName)"
						if player state is playing then
							pause
							set end of pausedPlayers to "\(appName)"
						end if
					end tell
				end if
			end try
			""")
		}
	}

	scriptParts.append("return pausedPlayers")
	let script = scriptParts.joined(separator: "\n\n")

	let appleScript = NSAppleScript(source: script)
	var error: NSDictionary?
	guard let resultDescriptor = appleScript?.executeAndReturnError(&error) else {
		if let error {
			mediaLogger.error("Failed to pause media apps: \(error)")
			mediaControlErrorCount += 1
			if mediaControlErrorCount >= 3 {
				mediaControlDisabled = true
			}
		}
		return []
	}

	var pausedPlayers: [String] = []
	let count = resultDescriptor.numberOfItems

	if count > 0 {
		for i in 1...count {
			if let item = resultDescriptor.atIndex(i)?.stringValue {
				pausedPlayers.append(item)
			}
		}
	}

	mediaLogger.notice("Paused media players: \(pausedPlayers.joined(separator: ", "))")

	return pausedPlayers
}

func resumeMediaApplications(_ players: [String]) {
	guard !players.isEmpty else { return }

	let validPlayers = players.filter { installedMediaPlayers.keys.contains($0) }
	if validPlayers.isEmpty {
		return
	}

	var scriptParts: [String] = []

	for player in validPlayers {
		if player == "VLC" {
			scriptParts.append("""
			try
				if application id "org.videolan.vlc" is running then
					tell application id "org.videolan.vlc" to play
				end if
			end try
			""")
		} else {
			scriptParts.append("""
			try
				if application "\(player)" is running then
					tell application "\(player)" to play
				end if
			end try
			""")
		}
	}

	let script = scriptParts.joined(separator: "\n\n")

	let appleScript = NSAppleScript(source: script)
	var error: NSDictionary?
	appleScript?.executeAndReturnError(&error)
	if let error {
		mediaLogger.error("Failed to resume media apps: \(error)")
	}
}

func sendMediaKey() {
	guard ensureMediaEventPostingAccess() else {
		return
	}

	let nxKeyTypePlay: UInt32 = 16

	func postKeyEvent(down: Bool) {
		let flags: NSEvent.ModifierFlags = down ? .init(rawValue: 0xA00) : .init(rawValue: 0xB00)
		let data1 = Int((nxKeyTypePlay << 16) | (down ? 0xA << 8 : 0xB << 8))
		if let event = NSEvent.otherEvent(with: .systemDefined,
		                                  location: .zero,
		                                  modifierFlags: flags,
		                                  timestamp: 0,
		                                  windowNumber: 0,
		                                  context: nil,
		                                  subtype: 8,
		                                  data1: data1,
		                                  data2: -1) {
			event.cgEvent?.post(tap: .cghidEventTap)
		}
	}

	postKeyEvent(down: true)
	postKeyEvent(down: false)
}

private func ensureMediaEventPostingAccess() -> Bool {
	if Thread.isMainThread {
		return requestMediaEventPostingAccess()
	}
	return DispatchQueue.main.sync {
		requestMediaEventPostingAccess()
	}
}

private func requestMediaEventPostingAccess() -> Bool {
	if CGPreflightPostEventAccess() {
		return true
	}

	let granted = CGRequestPostEventAccess()
	guard granted else {
		mediaLogger.error("Event posting permission denied while sending media key; opening Accessibility settings.")
		guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
			mediaLogger.error("Failed to construct Accessibility settings URL")
			return false
		}
		NSWorkspace.shared.open(url)
		return false
	}

	return true
}
