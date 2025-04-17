import Foundation

extension FileManager {
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    static func createTempDirectory() -> URL {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ECGExports", isDirectory: true)
        
        try? FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return tempDirectoryURL
    }
    
    static func clearTempDirectory() {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ECGExports", isDirectory: true)
        
        try? FileManager.default.removeItem(at: tempDirectoryURL)
    }
} 