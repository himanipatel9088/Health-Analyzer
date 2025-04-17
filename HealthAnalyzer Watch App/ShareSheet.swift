import SwiftUI
import WatchKit

struct ShareSheet: View {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var csvPreview: String = ""
    @State private var showPreview = false
    
    private func shareFile(_ url: URL) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Could not access documents directory"
            showError = true
            return
        }
        
        let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
        
        do {
            // If a file already exists at the destination, remove it
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file to documents directory
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Share the file from documents directory
            WKExtension.shared().openSystemURL(destinationURL)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        } catch {
            print("Error preparing file for sharing: \(error.localizedDescription)")
            errorMessage = "Error preparing file: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func createPreviewText(_ fullContent: String) -> String {
        let lines = fullContent.components(separatedBy: .newlines)
        var preview = ""
        
        // Add header information (first 5 lines)
        for i in 0..<min(5, lines.count) {
            preview += lines[i] + "\n"
        }
        
        preview += "\n[Voltage Data Preview]\n"
        
        // Add first 3 voltage measurements
        var voltageDataStartIndex = lines.firstIndex(where: { $0.contains("Time(s),Voltage") }) ?? 0
        voltageDataStartIndex += 1 // Skip the header line
        
        for i in voltageDataStartIndex..<min(voltageDataStartIndex + 3, lines.count) {
            preview += lines[i] + "\n"
        }
        
        preview += "...\n"
        
        // Add total number of measurements
        let totalMeasurements = lines.count - voltageDataStartIndex
        preview += "\nTotal Measurements: \(totalMeasurements)"
        
        return preview
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Share ECG Data")
                    .font(.headline)
                
                if let url = activityItems.first as? URL {
                    if showPreview {
                        Text(csvPreview)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(5)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        do {
                            // Check if file exists
                            guard FileManager.default.fileExists(atPath: url.path) else {
                                print("File does not exist at path: \(url.path)")
                                errorMessage = "File not found"
                                showError = true
                                return
                            }
                            
                            // Try to read file attributes
                            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                            print("File size: \(attributes[.size] ?? 0) bytes")
                            
                            // Attempt to read the file
                            let fullContent = try String(contentsOf: url, encoding: .utf8)
                            print("Successfully read CSV data, length: \(fullContent.count) characters")
                            
                            // Create preview of the content
                            csvPreview = createPreviewText(fullContent)
                            showPreview = true
                        } catch {
                            print("Error reading CSV file: \(error.localizedDescription)")
                            errorMessage = "Error reading file: \(error.localizedDescription)"
                            showError = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Preview Data")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        print("Attempting to share file at: \(url.path)")
                        shareFile(url)
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 40))
                            Text("Share ECG Data")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Text("No data to share")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
} 