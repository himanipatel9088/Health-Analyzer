//
//  HealthManager.swift
//  HealthAnalyzer
//
//  Created by Himani Patel on 11/04/25.
//

import HealthKit
import WatchKit

class HealthManager: ObservableObject {
    // MARK: - Types
    struct ECGSampleWithSymptoms: Identifiable, Equatable {
        let id = UUID()
        let sample: HKElectrocardiogram
        let symptoms: [String]
        let reportedSymptoms: [String]
        
        static func == (lhs: ECGSampleWithSymptoms, rhs: ECGSampleWithSymptoms) -> Bool {
            lhs.symptoms == rhs.symptoms && lhs.reportedSymptoms == rhs.reportedSymptoms
        }
    }
    
    // MARK: - Properties
    let healthStore = HKHealthStore()
    
    @Published var ecgSamplesWithSymptoms: [ECGSampleWithSymptoms] = [] {
        didSet {
            print("ECG samples updated. Count: \(ecgSamplesWithSymptoms.count)")
            for sample in ecgSamplesWithSymptoms {
                print("Sample ID: \(sample.id)")
                print("Symptoms: \(sample.symptoms)")
                print("Reported Symptoms: \(sample.reportedSymptoms)")
            }
        }
    }
    @Published var isECGAvailable = false
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    init() {
        checkECGAvailability()
    }
    
    // MARK: - Private Methods
    private func checkECGAvailability() {
        let ecgType = HKObjectType.electrocardiogramType()
        isECGAvailable = HKHealthStore.isHealthDataAvailable() &&
                        healthStore.authorizationStatus(for: ecgType) == .sharingAuthorized
    }
    
    private func getSymptomsFromECG(_ ecg: HKElectrocardiogram) -> (symptoms: [String], reportedSymptoms: [String]) {
        var symptoms: [String] = []
        var reportedSymptoms: [String] = []
        print("\nAnalyzing ECG sample from \(ecg.startDate)")
        
        // Check classification
        print("ECG Classification: \(ecg.classification.rawValue)")
        switch ecg.classification {
        case .atrialFibrillation:
            symptoms.append("Atrial Fibrillation detected")
        case .inconclusiveLowHeartRate:
            symptoms.append("Low Heart Rate (inconclusive)")
        case .inconclusiveHighHeartRate:
            symptoms.append("High Heart Rate (inconclusive)")
        case .inconclusivePoorReading:
            symptoms.append("Poor Reading Quality")
        case .inconclusiveOther:
            symptoms.append("Inconclusive Reading")
        case .sinusRhythm:
            symptoms.append("Normal Sinus Rhythm")
        @unknown default:
            symptoms.append("Unknown Classification")
        }
        
        // Check symptoms status
        print("Symptoms Status: \(ecg.symptomsStatus.rawValue)")
        if ecg.symptomsStatus == .present {
            reportedSymptoms.append("Symptoms reported")
        }
        
        // Check average heart rate
        if let avgHeartRate = ecg.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute())) {
            print("Average Heart Rate: \(Int(avgHeartRate)) BPM")
            if avgHeartRate > 100 {
                symptoms.append("Tachycardia (High Heart Rate)")
            } else if avgHeartRate < 60 {
                symptoms.append("Bradycardia (Low Heart Rate)")
            }
        } else {
            print("No average heart rate available")
        }
        
        print("Total symptoms found: \(symptoms.count)")
        print("Total reported symptoms: \(reportedSymptoms.count)")
        return (symptoms, reportedSymptoms)
    }
    
    // MARK: - Public Methods
    func requestECGPermission() {
        print("Requesting ECG permissions...")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is not available on this device"
            return
        }
        
        let ecgType = HKObjectType.electrocardiogramType()
        let typesToRead: Set<HKObjectType> = [ecgType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            if success {
                print("ECG permission granted")
                self?.checkECGAvailability()
                self?.fetchECGData()
            } else if let error = error {
                print("Error requesting ECG permission: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to get ECG permissions: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func fetchECGData() {
        print("Fetching ECG data...")
        
        let ecgType = HKObjectType.electrocardiogramType()
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            if let error = error {
                print("Error fetching ECG data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Error fetching ECG data: \(error.localizedDescription)"
                }
                return
            }
            
            guard let samples = samples as? [HKElectrocardiogram] else {
                print("No ECG samples found or invalid type")
                DispatchQueue.main.async {
                    self?.errorMessage = "No ECG readings found. Please ensure your Apple Watch supports ECG and try taking a reading."
                }
                return
            }
            
            print("Found \(samples.count) ECG samples")
            // Convert ECG samples to ECGSampleWithSymptoms with proper symptom analysis
            let processedSamples = samples.map { sample in
                let (symptoms, reportedSymptoms) = self?.getSymptomsFromECG(sample) ?? ([], [])
                return ECGSampleWithSymptoms(
                    sample: sample,
                    symptoms: symptoms,
                    reportedSymptoms: reportedSymptoms
                )
            }
            
            DispatchQueue.main.async {
                self?.ecgSamplesWithSymptoms = processedSamples
                self?.errorMessage = nil
            }
        }
        
        healthStore.execute(query)
    }

}
