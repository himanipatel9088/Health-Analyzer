//
//  UploadManger.swift
//  HealthAnalyzer Watch App
//
//  Created by Himani Patel on 11/04/25.
//

import Foundation
import HealthKit
import WatchKit

class UploadManager: ObservableObject {
    @Published var isProcessing = false
    let healthStore = HKHealthStore()
    
    private func fetchVoltageData(_ ecgSample: HKElectrocardiogram) async throws -> [Double] {
        var voltageValues: [Double] = []
        
        // Create voltage query
        let query = HKElectrocardiogramQuery(ecgSample) { query, result in
            switch result {
            case .measurement(let measurement):
                if let voltageQuantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                    voltageValues.append(voltageQuantity.doubleValue(for: .volt()))
                }
            case .done:
                self.healthStore.stop(query)
            case .error(let error):
                print("Error fetching voltage data: \(error.localizedDescription)")
                self.healthStore.stop(query)
            }
        }
        
        // Execute query and wait for completion
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.healthStore.execute(query)
                // Wait for voltage data collection (max 5 seconds)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.healthStore.stop(query)
                    continuation.resume(returning: voltageValues)
                }
            }
        }
    }
    
    private func exportECGData(_ sample: HealthManager.ECGSampleWithSymptoms, voltageData: [Double]) -> String {
        var csvString = "ECG Recording\n"
        
        // Metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        csvString += "Date: \(dateFormatter.string(from: sample.sample.startDate))\n"
        
        if let heartRate = sample.sample.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute())) {
            csvString += String(format: "Heart Rate: %.0f BPM\n", heartRate)
        }
        
        // Classification and Symptoms
        csvString += "Classification: \(sample.symptoms.joined(separator: ", "))\n"
        if !sample.reportedSymptoms.isEmpty {
            csvString += "Reported Symptoms: \(sample.reportedSymptoms.joined(separator: ", "))\n"
        }
        
        // Voltage Data
        csvString += "\nTime(s),Voltage(mV)\n"
        for (index, voltage) in voltageData.enumerated() {
            let timeInSeconds = Double(index) / 500.0 // 500Hz sampling rate
            csvString += String(format: "%.3f,%.6f\n", timeInSeconds, voltage * 1000)
        }
        print("csvString report",csvString)
        return csvString
    }
    
    func saveAndShare(_ sample: HealthManager.ECGSampleWithSymptoms) async throws -> URL {
        await MainActor.run {
            isProcessing = true
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        let voltageData = try await fetchVoltageData(sample.sample)
        print("Fetched \(voltageData.count) voltage measurements")

        let exportDir = FileManager.createTempDirectory()
        print("Created export directory at: \(exportDir.path)")

        let fileName = "ECG_\(Int(sample.sample.startDate.timeIntervalSince1970)).csv"
        let fileURL = exportDir.appendingPathComponent(fileName)
        print("Will save CSV to: \(fileURL.path)")

        let csvContent = exportECGData(sample, voltageData: voltageData)
        print("Generated CSV content with \(csvContent.count) characters")

        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // Verify file was written
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                print("Successfully wrote CSV file. Size: \(attributes[.size] ?? 0) bytes")

                // ✅ Upload to webhook.site (replace with your unique URL)
                if let webhookURL = URL(string: "https://webhook.site/d2e94be9-72b8-4efb-b286-c83691fd2a7b") {
                    uploadCSVFile(fileURL: fileURL, to: webhookURL)
                } else {
                    print("❌ Invalid webhook URL")
                }

                return fileURL
            } else {
                print("❌ File was not created at expected path")
                throw ExportError.saveFailed
            }
        } catch {
            print("❌ Failed to save CSV file: \(error.localizedDescription)")
            throw ExportError.saveFailed
        }
    }

    func uploadCSVFile(fileURL: URL, to endpoint: URL) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        let fieldName = "file"
        let fileName = fileURL.lastPathComponent
        let mimeType = "text/csv"

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        // Multipart form header
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

        // File content
        guard let fileData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read CSV file for upload")
            return
        }
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)

        // Closing boundary
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Upload task
        let task = URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
            if let error = error {
                print("❌ Upload error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Upload response status: \(httpResponse.statusCode)")
            }

            if let responseData = responseData, let responseText = String(data: responseData, encoding: .utf8) {
                print("✅ Server response:\n\(responseText)")
            }
        }

        task.resume()
    }

    enum ExportError: Error {
        case saveFailed
        
        var localizedDescription: String {
            switch self {
            case .saveFailed:
                return "Failed to save ECG data"
            }
        }
    }
}
