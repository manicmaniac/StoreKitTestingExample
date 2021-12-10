//
//  StoreKitTestingExampleTests.swift
//  StoreKitTestingExampleTests
//
//  Created by Ryosuke Ito on 12/9/21.
//

import StoreKit
import StoreKitTest
import XCTest
@testable import StoreKitTestingExample

class StoreKitTestingExampleTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Default")
        session.clearTransactions()
        session.resetToDefaultState()
        session.disableDialogs = true
    }

    func testRequestProducts() {
        let expectation = self.expectation(description: "SKProductsRequest should finish")
        let productsRequest = SKProductsRequest(productIdentifiers: ["com.example.auto-renewable"])
        let productsRequestHandler = ProductsRequestHandler { request, response in
            XCTAssertEqual(response.invalidProductIdentifiers, [])
            XCTAssertEqual(response.products.count, 1)
        } finish: { request in
            expectation.fulfill()
        } fail: { request, error in
            XCTFail(String(describing: error))
        }
        productsRequest.delegate = productsRequestHandler
        productsRequest.start()
        waitForExpectations(timeout: 1)
    }

    func testPurchase() {
        let expectation = self.expectation(description: "SKPaymentTransaction with purchased state should be received")
        var transactionStates: [SKPaymentTransactionState] = []
        let paymentTransactionObserver = PaymentTransactionObserver { queue, transactions in
            dispatchPrecondition(condition: .onQueue(.main))
            NSLog("--- Updating \(transactions.count) transactions")
            for transaction in transactions {
                NSLog("--- Processing transaction '\(String(describing: transaction.transactionIdentifier))'")
                transactionStates.append(transaction.transactionState)
                switch transaction.transactionState {
                case .purchasing:
                    NSLog("--- purchasing")
                case .purchased:
                    NSLog("--- purchased")
                    queue.finishTransaction(transaction)
                    expectation.fulfill()
                case .failed:
                    NSLog("--- failed")
                    queue.finishTransaction(transaction)
                case .restored:
                    NSLog("--- restored")
                    XCTFail("SKPaymentTransaction with restored state should not be received")
                case .deferred:
                    NSLog("--- deferred")
                    XCTFail("SKPaymentTransaction with deferred state should not be received")
                @unknown default:
                    break
                }
            }
        } removedTransactions: { queue, transactions in
            // Occasionally it might reach here
        } restoreCompletedTransactionsFinished: { queue in
            XCTFail(".restoreCompletedTransactionsFinished should not be called")
        }
        let product = MockSKProduct()
        let payment = SKPayment(product: product)
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.add(paymentTransactionObserver)
        paymentQueue.add(payment)
        waitForExpectations(timeout: 1)
        XCTAssertTrue((1...2) ~= transactionStates.count)
        XCTAssertEqual(transactionStates.last, .purchased)
    }
}

private class MockSKProductSubscriptionPeriod: SKProductSubscriptionPeriod {
    override var numberOfUnits: Int {
        return 1
    }

    override var unit: SKProduct.PeriodUnit {
        return .month
    }
}

private class MockSKProduct: SKProduct {
    override var productIdentifier: String {
        return "com.example.auto-renewable"
    }

    override var price: NSDecimalNumber {
        return 0.99
    }

    override var priceLocale: Locale {
        return Locale(identifier: "en_US@currency=USD")
    }

    override var subscriptionGroupIdentifier: String? {
        return "51154BEF"
    }

    override var subscriptionPeriod: SKProductSubscriptionPeriod? {
        return MockSKProductSubscriptionPeriod()
    }
}

private class PaymentTransactionObserver: NSObject, SKPaymentTransactionObserver {
    private let paymentQueue: SKPaymentQueue
    private let updatedTransactionsHandler: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)?
    private let removedTransactionsHandler: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)?
    private let restoreCompletedTransactionsFinishedHandler: ((SKPaymentQueue) -> Void)?

    init(paymentQueue: SKPaymentQueue = .default(),
         updatedTransactions: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)? = nil,
         removedTransactions: ((SKPaymentQueue, [SKPaymentTransaction]) -> Void)? = nil,
         restoreCompletedTransactionsFinished: ((SKPaymentQueue) -> Void)? = nil) {
        self.paymentQueue = paymentQueue
        self.updatedTransactionsHandler = updatedTransactions
        self.removedTransactionsHandler = removedTransactions
        self.restoreCompletedTransactionsFinishedHandler = restoreCompletedTransactionsFinished
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

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        restoreCompletedTransactionsFinishedHandler?(queue)
    }
}

private class ProductsRequestHandler: NSObject, SKProductsRequestDelegate {
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
