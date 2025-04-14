//
//  UploadManger.swift
//  HealthAnalyzer Watch App
//
//  Created by Himani Patel on 11/04/25.
//

import Foundation

class UploadManager {
    func uploadWaveform(_ waveform: [Double], to url: URL, completion: @escaping (Bool) -> Void) {
        guard let data = try? JSONSerialization.data(withJSONObject: waveform, options: []) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.uploadTask(with: request, from: data) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
}
