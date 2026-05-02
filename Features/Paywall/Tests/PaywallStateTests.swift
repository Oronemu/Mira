import Foundation
import Testing
import CoreKit
import TestSupport
@testable import FeaturePaywall

@Suite("PaywallState")
@MainActor
struct PaywallStateTests {
    private static let sampleProducts: [SubscriptionProduct] = [
        SubscriptionProduct(
            id: SubscriptionPlan.monthly.appStoreProductID,
            plan: .monthly,
            displayName: "Monthly",
            displayPrice: "$5.99",
            currencyCode: "USD",
            introductoryOffer: .init(kind: .freeTrial(days: 7))
        ),
        SubscriptionProduct(
            id: SubscriptionPlan.yearly.appStoreProductID,
            plan: .yearly,
            displayName: "Yearly",
            displayPrice: "$49.99",
            currencyCode: "USD",
            introductoryOffer: .init(kind: .freeTrial(days: 7))
        ),
    ]

    @Test("load fetches products and defaults the selection to yearly")
    func loadDefaultsToYearly() async {
        let service = MockSubscriptionService(products: Self.sampleProducts)
        let state = PaywallState(context: .general, subscriptionService: service)

        await state.load()

        #expect(state.products.count == 2)
        #expect(state.selectedProductID == SubscriptionPlan.yearly.appStoreProductID)
        #expect(state.isLoading == false)
    }

    @Test("purchaseSelected forwards the selected SKU and unlocks Pro")
    func purchaseUnlocksPro() async {
        let proStatus = SubscriptionStatus.pro(
            .init(plan: .yearly, renewalDate: nil, isInTrial: true, source: .appStore)
        )
        let service = MockSubscriptionService(
            products: Self.sampleProducts,
            purchaseHandler: { _ in proStatus }
        )
        let state = PaywallState(context: .general, subscriptionService: service)
        await state.load()

        await state.purchaseSelected()

        let calls = await service.purchaseCalls
        #expect(calls == [SubscriptionPlan.yearly.appStoreProductID])
        #expect(state.didUnlockPro)
    }

    @Test("purchaseSelected swallows .userCancelled silently")
    func userCancelledIsSilent() async {
        let service = MockSubscriptionService(
            products: Self.sampleProducts,
            purchaseHandler: { _ in throw SubscriptionError.userCancelled }
        )
        let state = PaywallState(context: .general, subscriptionService: service)
        await state.load()

        await state.purchaseSelected()

        #expect(state.errorMessage == nil)
        #expect(state.didUnlockPro == false)
    }

    @Test("purchaseSelected surfaces other errors via errorMessage")
    func purchaseFailureSurfacesError() async {
        let service = MockSubscriptionService(
            products: Self.sampleProducts,
            purchaseHandler: { _ in throw SubscriptionError.networkUnavailable }
        )
        let state = PaywallState(context: .general, subscriptionService: service)
        await state.load()

        await state.purchaseSelected()

        #expect(state.errorMessage != nil)
        #expect(state.didUnlockPro == false)
    }

    @Test("redeem with empty code does not call the service")
    func redeemEmptyCode() async {
        let service = MockSubscriptionService(products: Self.sampleProducts)
        let state = PaywallState(context: .general, subscriptionService: service)

        await state.redeem(code: "   ")

        #expect(state.errorMessage != nil)
        let calls = await service.redeemCalls
        #expect(calls.isEmpty)
    }

    @Test("redeem forwards the trimmed code")
    func redeemForwards() async {
        let proStatus = SubscriptionStatus.pro(
            .init(plan: .yearly, renewalDate: nil, isInTrial: false, source: .redeemCode("GIFT"))
        )
        let service = MockSubscriptionService(
            products: Self.sampleProducts,
            redeemHandler: { _ in proStatus }
        )
        let state = PaywallState(context: .general, subscriptionService: service)

        await state.redeem(code: "  GIFT  ")

        let calls = await service.redeemCalls
        #expect(calls == ["GIFT"])
        #expect(state.didUnlockPro)
    }

    @Test("clearError zeroes the message")
    func clearErrorResets() async {
        let service = MockSubscriptionService(products: Self.sampleProducts)
        let state = PaywallState(context: .general, subscriptionService: service)
        await state.redeem(code: "")
        #expect(state.errorMessage != nil)

        state.clearError()
        #expect(state.errorMessage == nil)
    }

    @Test("PaywallContext.id is stable per case and entitlement")
    func contextIDsAreStable() {
        #expect(PaywallContext.general.id == "general")
        #expect(PaywallContext.feature(.hostedAI).id == "feature.hostedAI")
        #expect(PaywallContext.feature(.themesAndIcons).id == "feature.themesAndIcons")
        #expect(PaywallContext.feature(.hostedAI).id == PaywallContext.feature(.hostedAI).id)
    }
}
