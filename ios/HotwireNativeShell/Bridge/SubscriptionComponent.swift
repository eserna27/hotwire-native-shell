import Foundation
import HotwireNative
import StoreKit
import os

/// Stimulus: `static component = "subscription"`.
///
/// Events: `purchase`, `restore`, `status`, `finish`. The page sends store
/// subscription product ids. This shell buys through StoreKit 2 and replies
/// with the signed transaction (JWS). It does not finish the transaction
/// until `finish`, which the page sends after its server has verified it.
final class SubscriptionComponent: BridgeComponent {
    override class var name: String { "subscription" }

    override func onReceive(message: Message) {
        switch message.event {
        case "purchase", "restore", "status", "finish":
            enqueue(message)
        case "disconnect":
            break
        default:
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
        }
    }

    private var chain: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "SubscriptionComponent")
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func enqueue(_ message: Message) {
        let previous = chain
        chain = Task { @MainActor [weak self] in
            await previous?.value
            await self?.perform(message)
        }
    }

    @MainActor
    private func perform(_ message: Message) async {
        let request: SubscriptionRequest? = message.data()
        if request == nil && (message.event == "purchase" || message.event == "finish") {
            sendReply(message.event, status: "error", productIds: [], error: "invalid_payload")
            return
        }
        let parsed = request ?? SubscriptionRequest()
        let productIds = productIds(in: parsed)
        switch message.event {
        case "purchase":
            await purchase(parsed, productIds: productIds)
        case "restore":
            await restore(productIds: productIds)
        case "status":
            await status(productIds: productIds)
        case "finish":
            await finish(parsed, productIds: productIds)
        default:
            break
        }
    }

    @MainActor
    private func purchase(_ request: SubscriptionRequest, productIds: [String]) async {
        guard let productId = productIds.first else {
            sendReply("purchase", status: "error", productIds: productIds, error: "missing_product_id")
            return
        }
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
                sendReply("purchase", status: "error", productIds: productIds, error: "product_unavailable")
                return
            }
            let result = try await product.purchase(options: purchaseOptions(accountToken: request.accountToken))
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    sendReply("purchase", status: "error", productIds: productIds, error: "verification_failed")
                    return
                }
                let record = makeTransaction(
                    transaction,
                    jws: verification.jwsRepresentation,
                    acknowledged: false
                )
                sendReply("purchase", status: "success", productIds: productIds, transactions: [record])
            case .userCancelled:
                sendReply("purchase", status: "cancelled", productIds: productIds)
            case .pending:
                sendReply("purchase", status: "pending", productIds: productIds)
            @unknown default:
                sendReply("purchase", status: "error", productIds: productIds, error: "unknown")
            }
        } catch {
            let failure = failure(for: error)
            let label = failure.code ?? failure.status
            logger.warning("purchase failed: \(label, privacy: .public)")
            sendReply("purchase", status: failure.status, productIds: productIds, error: failure.code)
        }
    }

    @MainActor
    private func restore(productIds: [String]) async {
        do {
            try await AppStore.sync()
        } catch {
            let failure = failure(for: error)
            let label = failure.code ?? failure.status
            logger.warning("restore failed: \(label, privacy: .public)")
            sendReply("restore", status: failure.status, productIds: productIds, error: failure.code)
            return
        }
        let transactions = await entitlements(matching: productIds)
        sendReply("restore", status: "success", productIds: productIds, transactions: transactions)
    }

    @MainActor
    private func status(productIds: [String]) async {
        let transactions = await entitlements(matching: productIds)
        sendReply("status", status: "success", productIds: productIds, transactions: transactions)
    }

    @MainActor
    private func finish(_ request: SubscriptionRequest, productIds: [String]) async {
        let transactionId = request.transactionId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantedId = (transactionId?.isEmpty == false) ? transactionId : nil
        let wantedProduct = productIds.first
        if wantedId == nil && wantedProduct == nil {
            sendReply("finish", status: "error", productIds: productIds, error: "not_found")
            return
        }

        var finished: [SubscriptionTransaction] = []
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            guard shouldFinish(transaction, wantedId: wantedId, wantedProduct: wantedProduct) else { continue }
            await transaction.finish()
            finished.append(makeTransaction(transaction, jws: result.jwsRepresentation, acknowledged: true))
        }

        if !finished.isEmpty {
            sendReply("finish", status: "success", productIds: productIds, transactions: finished)
            return
        }

        if let wantedProduct, let latest = await Transaction.latest(for: wantedProduct), case .verified(let transaction) = latest {
            if wantedId == nil || wantedId == String(transaction.id) {
                let record = makeTransaction(transaction, jws: latest.jwsRepresentation, acknowledged: true)
                sendReply("finish", status: "success", productIds: productIds, transactions: [record])
                return
            }
        }
        sendReply("finish", status: "error", productIds: productIds, error: "not_found")
    }

    private func entitlements(matching productIds: [String]) async -> [SubscriptionTransaction] {
        var unfinished = Set<UInt64>()
        var unfinishedRecords: [SubscriptionTransaction] = []
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            guard matches(transaction.productID, productIds) else { continue }
            unfinished.insert(transaction.id)
            unfinishedRecords.append(makeTransaction(transaction, jws: result.jwsRepresentation, acknowledged: false))
        }

        var seen = Set<UInt64>()
        var transactions: [SubscriptionTransaction] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard matches(transaction.productID, productIds) else { continue }
            seen.insert(transaction.id)
            transactions.append(
                makeTransaction(
                    transaction,
                    jws: result.jwsRepresentation,
                    acknowledged: !unfinished.contains(transaction.id)
                )
            )
        }
        for record in unfinishedRecords {
            if let id = record.transactionId, let value = UInt64(id), seen.contains(value) { continue }
            transactions.append(record)
        }
        return transactions
    }

    /// A transaction id is unique, so it wins. A product id finishes every
    /// unfinished transaction for that subscription.
    private func shouldFinish(_ transaction: Transaction, wantedId: String?, wantedProduct: String?) -> Bool {
        if let wantedId {
            return String(transaction.id) == wantedId
        }
        if let wantedProduct {
            return transaction.productID == wantedProduct
        }
        return false
    }

    private func matches(_ productID: String, _ productIds: [String]) -> Bool {
        productIds.isEmpty || productIds.contains(productID)
    }

    private func productIds(in request: SubscriptionRequest) -> [String] {
        var ids: [String] = []
        func add(_ value: String?) {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return }
            if !ids.contains(trimmed) { ids.append(trimmed) }
        }
        add(request.productId)
        request.productIds?.forEach(add)
        return ids
    }

    private func purchaseOptions(accountToken: String?) -> Set<Product.PurchaseOption> {
        guard let raw = accountToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              let uuid = UUID(uuidString: raw) else {
            return []
        }
        return [.appAccountToken(uuid)]
    }

    private func makeTransaction(_ transaction: Transaction, jws: String, acknowledged: Bool) -> SubscriptionTransaction {
        let state: String
        if transaction.revocationDate != nil {
            state = "revoked"
        } else if let expiration = transaction.expirationDate, expiration < Date() {
            state = "expired"
        } else {
            state = "purchased"
        }
        return SubscriptionTransaction(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            purchaseToken: nil,
            orderId: nil,
            signedTransaction: jws,
            originalJson: nil,
            signature: nil,
            state: state,
            expiresAt: transaction.expirationDate.map { Self.iso8601.string(from: $0) },
            acknowledged: acknowledged,
            environment: environment(of: transaction),
            accountToken: transaction.appAccountToken?.uuidString
        )
    }

    private func environment(of transaction: Transaction) -> String? {
        guard #available(iOS 16.0, *) else { return nil }
        if transaction.environment == .production { return "production" }
        if transaction.environment == .sandbox { return "sandbox" }
        if transaction.environment == .xcode { return "xcode" }
        return nil
    }

    private func failure(for error: Error) -> (status: String, code: String?) {
        if let storeKit = error as? StoreKitError {
            switch storeKit {
            case .userCancelled:
                return ("cancelled", nil)
            case .networkError:
                return ("error", "network")
            case .notAvailableInStorefront:
                return ("error", "store_unavailable")
            default:
                return ("error", "unknown")
            }
        }
        if let purchase = error as? Product.PurchaseError {
            switch purchase {
            case .productUnavailable:
                return ("error", "product_unavailable")
            case .purchaseNotAllowed:
                return ("error", "store_unavailable")
            default:
                return ("error", "unknown")
            }
        }
        return ("error", "unknown")
    }

    private func sendReply(
        _ event: String,
        status: String,
        productIds: [String],
        transactions: [SubscriptionTransaction] = [],
        error: String? = nil
    ) {
        reply(to: event, with: SubscriptionReply(
            status: status,
            platform: "ios",
            productId: productIds.first,
            productIds: productIds,
            transactions: transactions,
            error: error,
            bundleId: Bundle.main.bundleIdentifier,
            packageName: nil
        ))
    }

    private struct SubscriptionRequest: Decodable {
        let productId: String?
        let productIds: [String]?
        let basePlanId: String?
        let offerToken: String?
        let accountToken: String?
        let transactionId: String?
        let purchaseToken: String?

        init(
            productId: String? = nil,
            productIds: [String]? = nil,
            basePlanId: String? = nil,
            offerToken: String? = nil,
            accountToken: String? = nil,
            transactionId: String? = nil,
            purchaseToken: String? = nil
        ) {
            self.productId = productId
            self.productIds = productIds
            self.basePlanId = basePlanId
            self.offerToken = offerToken
            self.accountToken = accountToken
            self.transactionId = transactionId
            self.purchaseToken = purchaseToken
        }

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case productIds = "product_ids"
            case basePlanId = "base_plan_id"
            case offerToken = "offer_token"
            case accountToken = "account_token"
            case transactionId = "transaction_id"
            case purchaseToken = "purchase_token"
        }
    }

    private struct SubscriptionTransaction: Encodable {
        let productId: String
        let transactionId: String?
        let originalTransactionId: String?
        let purchaseToken: String?
        let orderId: String?
        let signedTransaction: String?
        let originalJson: String?
        let signature: String?
        let state: String
        let expiresAt: String?
        let acknowledged: Bool
        let environment: String?
        let accountToken: String?

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case transactionId = "transaction_id"
            case originalTransactionId = "original_transaction_id"
            case purchaseToken = "purchase_token"
            case orderId = "order_id"
            case signedTransaction = "signed_transaction"
            case originalJson = "original_json"
            case signature
            case state
            case expiresAt = "expires_at"
            case acknowledged
            case environment
            case accountToken = "account_token"
        }
    }

    private struct SubscriptionReply: Encodable {
        let status: String
        let platform: String
        let productId: String?
        let productIds: [String]
        let transactions: [SubscriptionTransaction]
        let error: String?
        let bundleId: String?
        let packageName: String?

        enum CodingKeys: String, CodingKey {
            case status
            case platform
            case productId = "product_id"
            case productIds = "product_ids"
            case transactions
            case error
            case bundleId = "bundle_id"
            case packageName = "package_name"
        }
    }
}
