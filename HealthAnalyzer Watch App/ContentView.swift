//
//  ContentView.swift
//  HealthAnalyzerNew Watch App
//
//  Created by Himani Patel on 11/04/25.
//

import SwiftUI
import HealthKit
import WatchKit

struct WelcomeView: View {
    @Binding var showECGList: Bool
    @StateObject private var healthManager = HealthManager()
    @State private var showTakeECGGuidance = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text("HealthAnalyzer")
                .font(.title3)
                .fontWeight(.semibold)
            
            Button(action: {
                showTakeECGGuidance = true
            }) {
                VStack {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 30))
                    Text("Take New ECG")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                showECGList = true
            }) {
                VStack {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 30))
                    Text("View ECG History")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showTakeECGGuidance) {
            ECGGuidanceView()
        }
        .onAppear {
            healthManager.requestECGPermission()
        }
    }
}

struct ECGGuidanceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    
    var body: some View {
        TabView(selection: $currentStep) {
            // Step 1: Press Digital Crown
            VStack(spacing: 15) {
                Text("Step 1")
                    .font(.headline)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                Text("Press the Digital Crown")
                    .font(.body)
                
                Text("This will show your apps")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .tag(1)
            
            // Step 2: Locate ECG App
            VStack(spacing: 15) {
                Text("Step 2")
                    .font(.headline)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Find ECG App")
                    .font(.body)
                
                Text("Look for the heart icon\nwith ECG lines")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .tag(2)
            
            // Step 3: Position
            VStack(spacing: 15) {
                Text("Step 3")
                    .font(.headline)
                
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Get Ready")
                    .font(.body)
                
                Text("Rest your arms on a table\nor in your lap")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .tag(3)
            
            // Step 4: Take Reading
            VStack(spacing: 15) {
                Text("Step 4")
                    .font(.headline)
                
                Image(systemName: "timer")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Take ECG Reading")
                    .font(.body)
                
                Text("Hold your finger on the\nDigital Crown for 30 seconds")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .padding(.top)
            }
            .tag(4)
        }
        .tabViewStyle(PageTabViewStyle())
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .fontWeight(.bold)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    var onBuy: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                
                Text("For $4.99 get a CardiacTech over read and report of your ECG.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .minimumScaleFactor(0.8)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                
                Spacer(minLength: 8)
                
                Button(action: {
                    onBuy()
                    dismiss()
                }) {
                    Text("Buy")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 14))
                .buttonStyle(.plain)
                .foregroundColor(.gray)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct ECGSampleView: View {
    let sample: HealthManager.ECGSampleWithSymptoms
    @StateObject private var uploadManager = UploadManager()
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var fileURL: URL?
    @State private var showPaymentView = false
    @State private var showSuccessAlert = false
    @StateObject private var paymentManager = PaymentManager()
    
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
            
            // Analysis Button
            Button(action: {
                showPaymentView = true
            }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Get Analysis")
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 6)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPaymentView) {
            PaymentView {
                paymentManager.onPaymentSuccess = {
                    showSuccessAlert = true
                }
                paymentManager.onPaymentFailure = {
                    print("Payment failed")
                }
                paymentManager.startPayment()
            }
        }
        .alert("Thank You!", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your detailed ECG analysis will be delivered to you shortly.")
        }
    }
}

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var paymentManager = PaymentManager()
    @State private var showECGList = false
    
    var body: some View {
        if showECGList {
            ECGListView(showECGList: $showECGList)
        } else {
            WelcomeView(showECGList: $showECGList)
        }
    }
}

struct ECGListView: View {
    @StateObject private var healthManager = HealthManager()
    @Binding var showECGList: Bool
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact header
            HStack(spacing: 4) {
                Button(action: {
                    showECGList = false
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .fontWeight(.medium)
                }
                .frame(width: 16)
                
                Text("ECG History")
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            
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
                        ECGSampleView(sample: sample)
                    }
                }
            }
        }
        .onAppear {
            healthManager.requestECGPermission()
        }
        .onChange(of: healthManager.ecgSamplesWithSymptoms) { newSamples in
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
