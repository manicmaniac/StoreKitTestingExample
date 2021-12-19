//
//  StoreKitTestingExampleTests.swift
//  StoreKitTestingExampleTests
//
//  Created by Ryosuke Ito on 12/9/21.
//

import OSLog
import StoreKit
import StoreKitTest
import XCTest

private let logger = Logger(subsystem: "StoreKitTestingExampleTests", category: "AutoRenewableTests")

class AutoRenewableTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Default")
        session.clearTransactions()
        logger.debug("clear all transactions.")
        session.resetToDefaultState()
        session.disableDialogs = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
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
            logger.debug("updating \(transactions.count) transactions.")
            for transaction in transactions {
                logger.debug("processing \(transaction.transactionState) transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                transactionStates.append(transaction.transactionState)
                switch transaction.transactionState {
                case .purchasing:
                    break
                case .purchased:
                    queue.finishTransaction(transaction)
                    logger.debug("finished transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                    expectation.fulfill()
                case .failed:
                    if let error = transaction.error {
                        logger.error("transaction \(String(describing: transaction.transactionIdentifier)) failed with error \(error as NSError).")
                    }
                    queue.finishTransaction(transaction)
                    logger.debug("finished transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                case .restored:
                    XCTFail("SKPaymentTransaction with restored state should not be received")
                case .deferred:
                    XCTFail("SKPaymentTransaction with deferred state should not be received")
                @unknown default:
                    break
                }
            }
        }
        let product = MockSKProduct()
        let payment = SKPayment(product: product)
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.add(paymentTransactionObserver)
        logger.debug("added payment \(payment) to the payment queue.")
        paymentQueue.add(payment)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(transactionStates, [.purchasing, .purchased])
    }

    func testPurchase_whenAskToBuyApproved() {
        session.askToBuyEnabled = true
        let expectation = self.expectation(description: "SKPaymentTransaction with purchased state should be received")
        var transactionStates: [SKPaymentTransactionState] = []
        let paymentTransactionObserver = PaymentTransactionObserver { [unowned self] queue, transactions in
            dispatchPrecondition(condition: .onQueue(.main))
            logger.debug("updating \(transactions.count) transactions.")
            for transaction in transactions {
                logger.debug("processing \(transaction.transactionState) transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                transactionStates.append(transaction.transactionState)
                switch transaction.transactionState {
                case .purchasing:
                    break
                case .purchased:
                    queue.finishTransaction(transaction)
                    logger.debug("finished transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                    expectation.fulfill()
                case .failed:
                    if let error = transaction.error {
                        logger.error("transaction \(String(describing: transaction.transactionIdentifier)) failed with error \(error as NSError).")
                    }
                    queue.finishTransaction(transaction)
                    logger.debug("finished transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                case .restored:
                    XCTFail("SKPaymentTransaction with restored state should not be received")
                case .deferred:
                    do {
                        let pendingTransaction = try XCTUnwrap(self.session.allTransactions().first(where: \.pendingAskToBuyConfirmation))
                        try self.session.approveAskToBuyTransaction(identifier: pendingTransaction.identifier)
                        logger.debug("approved transaction with identifier \(pendingTransaction.identifier)")
                    } catch let error {
                        XCTFail(String(describing: error))
                    }
                @unknown default:
                    break
                }
            }
        }
        let product = MockSKProduct()
        let payment = SKPayment(product: product)
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.add(paymentTransactionObserver)
        logger.debug("added payment \(payment) to the payment queue.")
        paymentQueue.add(payment)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(transactionStates, [.purchasing, .deferred, .purchased])
    }

    func testPurchase_whenAskToBuyDeclined() {
        session.askToBuyEnabled = true
        let expectation = self.expectation(description: "SKPaymentTransaction with deferred state should be received")
        var transactionStates: [SKPaymentTransactionState] = []
        let paymentTransactionObserver = PaymentTransactionObserver { [unowned self] queue, transactions in
            dispatchPrecondition(condition: .onQueue(.main))
            logger.debug("updating \(transactions.count) transactions.")
            for transaction in transactions {
                logger.debug("processing \(transaction.transactionState) transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                transactionStates.append(transaction.transactionState)
                switch transaction.transactionState {
                case .purchasing:
                    break
                case .purchased:
                    queue.finishTransaction(transaction)
                    XCTFail("finished transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                case .failed:
                    if let error = transaction.error {
                        logger.error("transaction \(String(describing: transaction.transactionIdentifier)) failed with error \(error as NSError).")
                    }
                    queue.finishTransaction(transaction)
                    logger.debug("finished transaction with identifier \(String(describing: transaction.transactionIdentifier)).")
                case .restored:
                    XCTFail("SKPaymentTransaction with restored state should not be received")
                case .deferred:
                    do {
                        let pendingTransaction = try XCTUnwrap(self.session.allTransactions().first(where: \.pendingAskToBuyConfirmation))
                        try self.session.declineAskToBuyTransaction(identifier: pendingTransaction.identifier)
                        logger.debug("declined transaction with identifier \(pendingTransaction.identifier)")
                        expectation.fulfill()
                    } catch let error {
                        XCTFail(String(describing: error))
                    }
                @unknown default:
                    break
                }
            }
        }
        let product = MockSKProduct()
        let payment = SKPayment(product: product)
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.add(paymentTransactionObserver)
        logger.debug("added payment \(payment) to the payment queue.")
        paymentQueue.add(payment)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(transactionStates, [.purchasing, .deferred])
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
