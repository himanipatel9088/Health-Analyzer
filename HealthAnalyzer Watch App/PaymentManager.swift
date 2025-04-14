//
//  Untitled.swift
//  HealthAnalyzer
//
//  Created by Himani Patel on 11/04/25.
//

import Foundation
import PassKit

class PaymentManager: NSObject, ObservableObject {
    var onPaymentSuccess: (() -> Void)?
    var onPaymentFailure: (() -> Void)?

    func startPayment() {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            print("❌ Apple Pay is not available on this device.")
            onPaymentFailure?()
            return
        }

        guard PKPaymentAuthorizationController.canMakePayments(usingNetworks: PKPaymentRequest.availableNetworks()) else {
            print("❌ Apple Pay not available or no cards set up.")
            onPaymentFailure?()
            return
        }

        print("✅ Apple Pay is available.")

        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.RewardleApp"
        request.supportedNetworks = PKPaymentRequest.availableNetworks()
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "AU"
        request.currencyCode = "AUD"
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "ECG Analysis", amount: NSDecimalNumber(string: "4.99"))
        ]

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        controller.present { presented in
            if !presented {
                print("❌ Failed to present Apple Pay authorization.")
                self.onPaymentFailure?()
            }
        }
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension PaymentManager: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                        didAuthorizePayment payment: PKPayment,
                                        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Simulate successful payment
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        onPaymentSuccess?()
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
}
