import Foundation
import FirebaseFirestore
import UIKit

// MARK: - Session Service

final class SessionService {
    static let shared = SessionService()

    private init() {}

    private let throttleKey = "viefolio.lastSessionRecordAt"

    func recordSession(uid: String) async {
        let last = UserDefaults.standard.double(forKey: throttleKey)
        guard Date().timeIntervalSince1970 - last > 6 * 3600 else { return }

        let deviceId = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        }
        let osVersion = await MainActor.run { "iOS \(UIDevice.current.systemVersion)" }
        let location = await fetchIPLocation()

        do {
            try await Firestore.firestore()
                .collection("profiles").document(uid)
                .collection("sessions").document("ios-\(deviceId)")
                .setData([
                    "platform": "IOS",
                    "deviceModel": Self.deviceModelName(),
                    "osVersion": osVersion,
                    "location": location,
                    "lastSignIn": FieldValue.serverTimestamp(),
                ], merge: true)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: throttleKey)
        } catch {
            print("❌ RecordSession error: \(error)")
        }
    }

    private func fetchIPLocation() async -> String {
        guard let url = URL(string: "https://ipapi.co/json/") else { return "" }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
            let city = json["city"] as? String ?? ""
            let country = json["country_name"] as? String ?? ""
            return [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        } catch {
            return ""
        }
    }

    static func deviceModelName() -> String {
        #if targetEnvironment(simulator)
        let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        #endif

        let names: [String: String] = [
            "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,5": "iPhone 16e",
            "iPhone18,3": "iPhone 17", "iPhone18,1": "iPhone 17 Pro",
            "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,4": "iPhone Air",
        ]
        if let name = names[identifier] { return name }
        if identifier.hasPrefix("iPad") { return "iPad" }
        return identifier
    }
}
