import Foundation
import Observation
import StoreKit

@MainActor
@Observable
public final class CloudPassStore {
    public static let productIDs = [
        "com.iantodd.ontotheradio.pro.monthly",
        "com.iantodd.ontotheradio.pro.yearly"
    ]

    public var products: [Product] = []
    public var hasActiveSubscription: Bool = false
    public var statusNote: String = ""

    public init() {}

    public func refresh() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            var active = false
            for await verification in Transaction.currentEntitlements {
                if case .verified(let tx) = verification,
                   Self.productIDs.contains(tx.productID),
                   tx.revocationDate == nil {
                    active = true
                }
            }
            hasActiveSubscription = active
        } catch {
            statusNote = "Store unavailable offline"
        }
    }

    public func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    hasActiveSubscription = true
                    statusNote = "Onto Cloud active"
                }
            case .userCancelled:
                break
            case .pending:
                statusNote = "Purchase pending"
            @unknown default:
                break
            }
        } catch {
            statusNote = "Purchase failed"
        }
    }

    public func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
