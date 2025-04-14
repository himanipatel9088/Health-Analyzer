//
//  ContentView.swift
//  HealthAnalyzerNew Watch App
//
//  Created by Himani Patel on 11/04/25.
//

import SwiftUI
import HealthKit

struct ECGSampleView: View {
    let sample: HealthManager.ECGSampleWithSymptoms
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ECG Reading Information
            let ecgStartDate = sample.sample.startDate
            Text("ECG Reading")
                .font(.headline)
            
            Text("Date: \(ecgStartDate, style: .date)")
                .font(.subheadline)
            Text("Time: \(ecgStartDate, style: .time)")
                .font(.subheadline)
            
            // Average Heart Rate
            let avgHeartRate = sample.sample.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute()))
            Text("Average Heart Rate: \(avgHeartRate != nil ? "\(Int(avgHeartRate!)) BPM" : "N/A")")
                .font(.subheadline)
            
            // ECG Classification
            VStack(alignment: .leading, spacing: 2) {
                Text("ECG Results:")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                ForEach(sample.symptoms, id: \.self) { symptom in
                    if symptom != "Symptoms Present" && symptom != "Symptoms Not Set" {
                        Text("• \(symptom)")
                            .font(.subheadline)
                            .foregroundColor(symptom.contains("Normal") ? .green : .red)
                    }
                }
            }
            .padding(.vertical, 2)
            
            // Reported Symptoms if any
            if !sample.reportedSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reported Symptoms:")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    ForEach(sample.reportedSymptoms, id: \.self) { symptom in
                        Text("• \(symptom)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var paymentManager = PaymentManager()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPaymentAlert = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading ECG data...")
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else if healthManager.ecgSamplesWithSymptoms.isEmpty {
                Text("No ECG data available")
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(healthManager.ecgSamplesWithSymptoms, id: \.id) { sample in
                        Button(action: {
                            showPaymentAlert = true
                        }) {
                            ECGSampleView(sample: sample)
                        }
                    }
                }
            }
        }
        .onAppear {
            print("ContentView appeared")
            healthManager.requestECGPermission()
        }
        .onChange(of: healthManager.ecgSamplesWithSymptoms) { newSamples in
            print("ECG samples updated. Count: \(newSamples.count)")
            isLoading = false
        }
        .alert("Detailed Analysis", isPresented: $showPaymentAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Pay Now") {
                paymentManager.onPaymentSuccess = {
                    showSuccessAlert = true
                }
                paymentManager.onPaymentFailure = {
                    print("Payment failed")
                }
                paymentManager.startPayment()
            }
        } message: {
            Text("Get detailed analysis of your ECG reading")
        }
        .alert("Thank You!", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your detailed ECG analysis will be delivered to you shortly.")
        }
    }
}

#Preview {
    ContentView()
}
