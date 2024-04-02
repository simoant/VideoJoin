//
//  RevenueCatManager.swift
//  VideoJoin
//
//  Created by Anton Simonov on 29/3/24.
//

import Foundation
import RevenueCat

class RevenueCatManager {
    func hasActiveSubscription() async throws -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            log("Customer info\(customerInfo.entitlements.active)")
            return !customerInfo.entitlements.active.isEmpty
        } catch {
            throw err("Error obtaining subscription information")
        }
    }
}
