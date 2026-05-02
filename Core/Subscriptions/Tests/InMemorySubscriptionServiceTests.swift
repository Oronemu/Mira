import Foundation
import Testing
import CoreKit
@testable import Subscriptions

@Suite("InMemorySubscriptionService")
struct InMemorySubscriptionServiceTests {
    @Test("default status is free and default catalog has monthly + yearly")
    func defaultsAreFreeWithCanonicalCatalog() async throws {
        let service = InMemorySubscriptionService()

        let status = await service.status
        #expect(status == .free)

        let products = try await service.availableProducts()
        #expect(products.count == 2)
        #expect(products.contains(where: { $0.plan == .monthly }))
        #expect(products.contains(where: { $0.plan == .yearly }))
        for product in products {
            #expect(product.introductoryOffer != nil)
        }
    }

    @Test("purchase flips the status to .pro with appStore source")
    func purchaseUnlocksPro() async throws {
        let service = InMemorySubscriptionService()
        let yearlyID = SubscriptionPlan.yearly.appStoreProductID

        let status = try await service.purchase(productID: yearlyID)

        #expect(status.isPro)
        let pro = status.proDetails
        #expect(pro?.plan == .yearly)
        #expect(pro?.source == .appStore)
        #expect(pro?.isInTrial == true)
    }

    @Test("purchase with unknown product throws .productNotFound")
    func purchaseUnknownProduct() async {
        let service = InMemorySubscriptionService()
        await #expect(throws: SubscriptionError.self) {
            try await service.purchase(productID: "com.unknown")
        }
    }

    @Test("isEntitled is false for free, true for pro")
    func entitlementMirrorsStatus() async throws {
        let service = InMemorySubscriptionService()
        let beforePurchase = await service.isEntitled(to: .hostedAI)
        #expect(beforePurchase == false)

        _ = try await service.purchase(productID: SubscriptionPlan.monthly.appStoreProductID)
        let afterPurchase = await service.isEntitled(to: .hostedAI)
        #expect(afterPurchase == true)
    }

    @Test("redeem accepts a configured code and rejects an unknown one")
    func redeemValidAndInvalidCode() async throws {
        let service = InMemorySubscriptionService(
            validRedeemCodes: ["FRIENDS"]
        )

        await #expect(throws: SubscriptionError.self) {
            try await service.redeem(code: "BOGUS")
        }

        let status = try await service.redeem(code: "friends")
        #expect(status.isPro)
        #expect(status.proDetails?.source == .redeemCode("FRIENDS"))
    }

    @Test("redeem rejects a code the second time it's used")
    func redeemSingleUse() async throws {
        let service = InMemorySubscriptionService(validRedeemCodes: ["GIFT"])
        _ = try await service.redeem(code: "GIFT")

        await #expect(throws: SubscriptionError.self) {
            try await service.redeem(code: "GIFT")
        }
    }

    @Test("statusUpdates replays current status and emits new ones")
    func statusUpdatesStreamReplaysAndEmits() async throws {
        let service = InMemorySubscriptionService()

        let stream = service.statusUpdates
        var iterator = stream.makeAsyncIterator()

        // Replay should be `.free` immediately.
        let first = await iterator.next()
        #expect(first == .free)

        _ = try await service.purchase(productID: SubscriptionPlan.monthly.appStoreProductID)
        let second = await iterator.next()
        #expect(second?.isPro == true)
    }

    @Test("setStatus override broadcasts a custom status without going through purchase")
    func setStatusOverride() async {
        let service = InMemorySubscriptionService()
        let pro = SubscriptionStatus.pro(
            .init(plan: .yearly, renewalDate: nil, isInTrial: false, source: .testFlight)
        )

        await service.setStatus(pro)

        let observed = await service.status
        #expect(observed.isPro)
        #expect(observed.proDetails?.source == .testFlight)
    }
}
