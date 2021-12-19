//
//  TestHelper.swift
//  StoreKitTestingExampleTests
//
//  Created by Ryosuke Ito on 12/19/21.
//

import Foundation
import StoreKit

class PaymentTransactionObserver: NSObject, SKPaymentTransactionObserver {
    private let paymentQueue: SKPaymentQueue
    private let updatedTransactionsHandler: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)?
    var removedTransactionsHandler: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)?
    var restoreCompletedTransactionsFailedHandler: ((SKPaymentQueue, Error) -> Void)?
    var restoreCompletedTransactionsFinishedHandler: ((SKPaymentQueue) -> Void)?
    var updatedDownloadsHandler: ((SKPaymentQueue, [SKDownload]) -> Void)?
    var shouldAddStorePaymentHandler: ((SKPaymentQueue, SKPayment, SKProduct) -> Bool)?
    var revokeEntitlementsHandler: ((SKPaymentQueue, [String]) -> Void)?
    var changeStoreFrontHandler: ((SKPaymentQueue) -> Void)?

    init(paymentQueue: SKPaymentQueue = .default(),
         updatedTransactions: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)? = nil) {
        self.paymentQueue = paymentQueue
        self.updatedTransactionsHandler = updatedTransactions
        super.init()
        paymentQueue.add(self)
    }

    deinit {
        paymentQueue.remove(self)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        updatedTransactionsHandler?(queue, transactions)
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        removedTransactionsHandler?(queue, transactions)
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        restoreCompletedTransactionsFailedHandler?(queue, error)
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        restoreCompletedTransactionsFinishedHandler?(queue)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        updatedDownloadsHandler?(queue, downloads)
    }

    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return shouldAddStorePaymentHandler?(queue, payment, product) ?? true
    }

    func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
        revokeEntitlementsHandler?(queue, productIdentifiers)
    }

    func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue) {
        changeStoreFrontHandler?(queue)
    }
}

class ProductsRequestHandler: NSObject, SKProductsRequestDelegate {
    private let receiveResponseHandler: ((SKProductsRequest, SKProductsResponse) -> Void)?
    private let finishHandler: ((SKRequest) -> Void)?
    private let failHandler: ((SKRequest, Error) -> Void)?

    init(receiveResponse: ((SKProductsRequest, SKProductsResponse) -> Void)? = nil,
         finish: ((SKRequest) -> Void)? = nil,
         fail: ((SKRequest, Error) -> Void)? = nil) {
        self.receiveResponseHandler = receiveResponse
        self.finishHandler = finish
        self.failHandler = fail
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        receiveResponseHandler?(request, response)
    }

    func requestDidFinish(_ request: SKRequest) {
        finishHandler?(request)
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        failHandler?(request, error)
    }
}

extension SKPaymentTransactionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .purchasing:
            return "purchasing"
        case .purchased:
            return "purchased"
        case .failed:
            return "failed"
        case .restored:
            return "restored"
        case .deferred:
            return "deferred"
        @unknown default:
            return "unknown (\(rawValue)"
        }
    }
}
