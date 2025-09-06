//
//  ServiceManager.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import Foundation

struct ServiceSetting {
    let key: String
    let value: String
    let type: SettingType
    let comment: String?
    
    enum SettingType {
        case string
        case bool
        case int
        case float
    }
}

class ServiceManager: ObservableObject {
    static let shared = ServiceManager()
    
    @Published var services: [Services] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadMessage: String = ""
    
    let documentsDirectory: URL
    let servicesDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        servicesDirectory = documentsDirectory.appendingPathComponent("Services")
        
        createServicesDirectoryIfNeeded()
        loadExistingServices()
        loadDefaultServicesIfNeeded()
        let activeCount = services.filter { $0.isActive }.count
        Logger.shared.log("Active services: \(activeCount)/\(services.count)", type: "ServiceManager")
    }
    
    // MARK: - UserDefaults Persistence
    
    private func generateServiceUUID(from metadata: ServicesMetadata, folderName: String) -> UUID {
        let identifier = "\(metadata.sourceName)\(metadata.author.name)\(metadata.version)_\(folderName)"
        
        var hash: UInt64 = 5381
        for char in identifier.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        
        var uuidBytes: [UInt8] = []
        
        for i in 0..<8 {
            uuidBytes.append(UInt8((hash >> (i * 8)) & 0xFF))
        }
        
        var hash2: UInt64 = 2166136261
        for char in String(identifier.reversed()).utf8 {
            hash2 = (hash2 &* 16777619) ^ UInt64(char)
        }
        
        for i in 0..<8 {
            uuidBytes.append(UInt8((hash2 >> (i * 8)) & 0xFF))
        }
        
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        
        return NSUUID(uuidBytes: uuidBytes) as UUID
    }
    
    private func saveServiceStates() {
        let serviceStates = Dictionary(uniqueKeysWithValues: services.map { ($0.id.uuidString, $0.isActive) })
        UserDefaults.standard.set(serviceStates, forKey: "ServiceActiveStates")
        UserDefaults.standard.synchronize()
    }
    
    private func loadServiceState(for serviceId: UUID) -> Bool {
        guard let serviceStates = UserDefaults.standard.object(forKey: "ServiceActiveStates") as? [String: Bool] else {
            Logger.shared.log("No service states found in UserDefaults", type: "ServiceManager")
            return false
        }
        let state = serviceStates[serviceId.uuidString] ?? false
        return state
    }
    
    // MARK: - Public Methods
    
    func handlePotentialServiceURL(_ text: String) async -> Bool {
        guard isValidJSONURL(text) else { return false }
        
        await downloadService(from: text)
        return true
    }
    
    func downloadService(from jsonURL: String) async {
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            downloadMessage = "Downloading service..."
        }
        
        do {
            await updateProgress(0.2, "Downloading metadata...")
            let metadata = try await downloadAndParseMetadata(from: jsonURL)
            
            await updateProgress(0.5, "Downloading JavaScript...")
            let jsContent = try await downloadJavaScript(from: metadata.scriptUrl)
            
            await updateProgress(0.8, "Saving files...")
            let service = try await saveService(metadata: metadata, jsContent: jsContent, metadataUrl: jsonURL)
            
            await MainActor.run {
                self.services.append(service)
                self.saveServiceStates()
                self.downloadProgress = 1.0
                self.downloadMessage = "Service downloaded successfully!"
            }
            
            Logger.shared.log("Successfully downloaded service: \(metadata.sourceName)", type: "ServiceManager")
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.downloadMessage = ""
            }
            
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.downloadMessage = ""
            }
            Logger.shared.log("Failed to download service from \(jsonURL): \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    func removeService(_ service: Services) {
        do {
            let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
            if FileManager.default.fileExists(atPath: servicePath.path) {
                try FileManager.default.removeItem(at: servicePath)
            }
            
            services.removeAll { $0.id == service.id }
            
            if var serviceStates = UserDefaults.standard.object(forKey: "ServiceActiveStates") as? [String: Bool] {
                serviceStates.removeValue(forKey: service.id.uuidString)
                UserDefaults.standard.set(serviceStates, forKey: "ServiceActiveStates")
            }
            
            Logger.shared.log("Removed service: \(service.metadata.sourceName)", type: "ServiceManager")
        } catch {
            Logger.shared.log("Failed to remove service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    func setServiceState(_ service: Services, isActive: Bool) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index].isActive = isActive
            saveServiceStates()
            Logger.shared.log("Set service \(service.metadata.sourceName) (ID: \(service.id.uuidString)) to \(isActive ? "active" : "inactive")", type: "ServiceManager")
        } else {
            Logger.shared.log("Could not find service \(service.metadata.sourceName) (ID: \(service.id.uuidString)) to update state", type: "ServiceManager")
        }
    }
    
    func toggleServiceState(_ service: Services) {
        setServiceState(service, isActive: !service.isActive)
    }
    
    var activeServices: [Services] {
        return services.filter { $0.isActive }
    }
    
    func refreshDefaultServices() async {
        UserDefaults.standard.set(false, forKey: "DefaultServicesLoaded")
        await loadDefaultServices()
    }
    
    // MARK: Search Methods
    func searchInActiveServices(query: String) async -> [(service: Services, results: [SearchItem])] {
        let activeServicesList = activeServices
        
        Logger.shared.log("Starting search for '\(query)' across \(activeServicesList.count) active services", type: "ServiceManager")
        
        guard !activeServicesList.isEmpty else {
            Logger.shared.log("No active services found for search", type: "ServiceManager")
            return []
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            downloadMessage = "Searching..."
        }
        
        var allResults: [(service: Services, results: [SearchItem])] = []
        let totalServices = activeServicesList.count
        
        for (index, service) in activeServicesList.enumerated() {
            let progress = Double(index) / Double(totalServices)
            await updateProgress(progress, "Searching \(service.metadata.sourceName)...")
            
            Logger.shared.log("Searching in service: \(service.metadata.sourceName)", type: "ServiceManager")
            
            let results = await searchInService(service: service, query: query)
            allResults.append((service: service, results: results))
            
            Logger.shared.log("Found \(results.count) results in \(service.metadata.sourceName)", type: "ServiceManager")
        }
        
        await MainActor.run {
            self.isDownloading = false
            self.downloadProgress = 0.0
            self.downloadMessage = ""
        }
        
        let totalResults = allResults.reduce(0) { $0 + $1.results.count }
        Logger.shared.log("Search completed: \(totalResults) total results from \(allResults.count) services", type: "ServiceManager")
        
        return allResults
    }
    
    func searchInActiveServicesProgressively(query: String, onResult: @escaping @MainActor (Services, [SearchItem]) -> Void, onComplete: @escaping @MainActor () -> Void) async {
        let activeServicesList = activeServices
        
        Logger.shared.log("Starting progressive search for '\(query)' across \(activeServicesList.count) active services", type: "ServiceManager")
        
        guard !activeServicesList.isEmpty else {
            Logger.shared.log("No active services found for search", type: "ServiceManager")
            await MainActor.run {
                onComplete()
            }
            return
        }
        
        for service in activeServicesList {
            Logger.shared.log("Searching in service: \(service.metadata.sourceName)", type: "ServiceManager")
            
            let results = await searchInService(service: service, query: query)
            
            await MainActor.run {
                onResult(service, results)
            }
            
            Logger.shared.log("Found \(results.count) results in \(service.metadata.sourceName)", type: "ServiceManager")
        }
        
        await MainActor.run {
            onComplete()
        }
        
        let totalServices = activeServicesList.count
        Logger.shared.log("Progressive search completed for \(totalServices) services", type: "ServiceManager")
    }
    
    private func searchInService(service: Services, query: String) async -> [SearchItem] {
        let jsController = JSController()
        
        let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "ServiceManager")
            return []
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            jsController.loadScript(jsContent)
            
            return await withCheckedContinuation { continuation in
                jsController.fetchJsSearchResults(keyword: query, module: service) { results in
                    continuation.resume(returning: results)
                }
            }
        } catch {
            Logger.shared.log("Failed to load JavaScript for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidJSONURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        return url.scheme != nil &&
        (url.pathExtension.lowercased() == "json" ||
         text.lowercased().contains(".json"))
    }
    
    private func downloadAndParseMetadata(from urlString: String) async throws -> ServicesMetadata {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.custom.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.downloadFailed
        }
        
        do {
            let metadata = try JSONDecoder().decode(ServicesMetadata.self, from: data)
            return metadata
        } catch {
            throw ServiceError.invalidJSON
        }
    }
    
    private func downloadJavaScript(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidScriptURL
        }
        
        let (data, response) = try await URLSession.custom.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.scriptDownloadFailed
        }
        
        guard let jsContent = String(data: data, encoding: .utf8) else {
            throw ServiceError.invalidScriptContent
        }
        
        return jsContent
    }
    
    private func saveService(metadata: ServicesMetadata, jsContent: String, metadataUrl: String) async throws -> Services {
        let tempServiceId = UUID()
        let serviceFolderName = "\(metadata.sourceName.replacingOccurrences(of: " ", with: "_"))_\(tempServiceId.uuidString.prefix(8))"
        let servicePath = servicesDirectory.appendingPathComponent(serviceFolderName)
        try FileManager.default.createDirectory(at: servicePath, withIntermediateDirectories: true)
        
        let jsonData = try JSONEncoder().encode(metadata)
        let jsonPath = servicePath.appendingPathComponent("metadata.json")
        try jsonData.write(to: jsonPath)
        
        let jsPath = servicePath.appendingPathComponent("script.js")
        try jsContent.write(to: jsPath, atomically: true, encoding: .utf8)
        
        let serviceId = generateServiceUUID(from: metadata, folderName: serviceFolderName)
        
        let service = Services(
            id: serviceId,
            metadata: metadata,
            localPath: serviceFolderName,
            metadataUrl: metadataUrl,
            isActive: false
        )
        
        return service
    }
    
    private func createServicesDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: servicesDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: servicesDirectory, withIntermediateDirectories: true)
                Logger.shared.log("Created Services directory", type: "ServiceManager")
            } catch {
                Logger.shared.log("Failed to create Services directory: \(error.localizedDescription)", type: "ServiceManager")
            }
        }
    }
    
    private func loadExistingServices() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: servicesDirectory, includingPropertiesForKeys: nil)
            
            for folder in contents where folder.hasDirectoryPath {
                if let service = loadService(from: folder) {
                    services.append(service)
                }
            }
            
            Logger.shared.log("Loaded \(services.count) existing services", type: "ServiceManager")
        } catch {
            Logger.shared.log("Failed to load existing services: \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    private func loadService(from folderURL: URL) -> Services? {
        let metadataPath = folderURL.appendingPathComponent("metadata.json")
        
        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: metadataPath)
            let metadata = try JSONDecoder().decode(ServicesMetadata.self, from: data)
            
            let serviceIdPath = folderURL.appendingPathComponent("service_id.json")
            if FileManager.default.fileExists(atPath: serviceIdPath.path) {
                try? FileManager.default.removeItem(at: serviceIdPath)
            }
            
            let serviceId = generateServiceUUID(from: metadata, folderName: folderURL.lastPathComponent)
            let savedState = loadServiceState(for: serviceId)
            
            return Services(
                id: serviceId,
                metadata: metadata,
                localPath: folderURL.lastPathComponent,
                metadataUrl: "",
                isActive: savedState
            )
        } catch {
            Logger.shared.log("Failed to load service from \(folderURL.lastPathComponent): \(error.localizedDescription)", type: "ServiceManager")
            return nil
        }
    }
    
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            self.downloadProgress = progress
            self.downloadMessage = message
        }
    }
    
    // MARK: - Default Services
    
    private func loadDefaultServicesIfNeeded() {
        if UserDefaults.standard.bool(forKey: "DefaultServicesLoaded") {
            return
        }
        
        Task {
            await loadDefaultServices()
        }
    }
    
    private func loadDefaultServices() async {
        let defaultServiceURLs = [
            "https://raw.githubusercontent.com/cranci1/Sora-Modules/refs/heads/main/Emby/Emby.json",
            "https://raw.githubusercontent.com/cranci1/Sora-Modules/refs/heads/main/JellyFin/jellyfin.json"
        ]
        
        Logger.shared.log("Loading default services...", type: "ServiceManager")
        
        for serviceURL in defaultServiceURLs {
            do {
                Logger.shared.log("Loading default service from: \(serviceURL)", type: "ServiceManager")
                
                let metadata = try await downloadAndParseMetadata(from: serviceURL)
                
                let existingService = services.first { service in
                    service.metadata.sourceName == metadata.sourceName &&
                    service.metadata.author.name == metadata.author.name &&
                    service.metadata.version == metadata.version
                }
                
                if existingService != nil {
                    Logger.shared.log("Default service \(metadata.sourceName) already exists, skipping", type: "ServiceManager")
                    continue
                }
                
                let jsContent = try await downloadJavaScript(from: metadata.scriptUrl)
                let service = try await saveService(metadata: metadata, jsContent: jsContent, metadataUrl: serviceURL)
                
                await MainActor.run {
                    self.services.append(service)
                }
                
                Logger.shared.log("Successfully loaded default service: \(metadata.sourceName)", type: "ServiceManager")
                
            } catch {
                Logger.shared.log("Failed to load default service from \(serviceURL): \(error.localizedDescription)", type: "ServiceManager")
            }
        }
        
        await MainActor.run {
            self.saveServiceStates()
        }
        
        UserDefaults.standard.set(true, forKey: "DefaultServicesLoaded")
        Logger.shared.log("Finished loading default services", type: "ServiceManager")
    }
    
    // MARK: - Service Settings
    
    func getServiceSettings(_ service: Services) -> [ServiceSetting] {
        let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "ServiceManager")
            return []
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            return parseSettingsFromJS(jsContent)
        } catch {
            Logger.shared.log("Failed to read JavaScript file for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
            return []
        }
    }
    
    func updateServiceSettings(_ service: Services, settings: [ServiceSetting]) -> Bool {
        let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "ServiceManager")
            return false
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            let updatedJS = updateSettingsInJS(jsContent, with: settings)
            try updatedJS.write(to: jsPath, atomically: true, encoding: .utf8)
            Logger.shared.log("Successfully updated settings for service: \(service.metadata.sourceName)", type: "ServiceManager")
            return true
        } catch {
            Logger.shared.log("Failed to update settings for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
            return false
        }
    }
    
    private func parseSettingsFromJS(_ jsContent: String) -> [ServiceSetting] {
        var settings: [ServiceSetting] = []
        let lines = jsContent.components(separatedBy: .newlines)
        
        var inSettingsSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("// Settings start") {
                inSettingsSection = true
                continue
            }
            
            if trimmedLine.contains("// Settings end") {
                break
            }
            
            if inSettingsSection && trimmedLine.hasPrefix("const ") {
                if let setting = parseSettingLine(trimmedLine) {
                    settings.append(setting)
                }
            }
        }
        
        return settings
    }
    
    private func parseSettingLine(_ line: String) -> ServiceSetting? {
        let pattern = #"const\s+(\w+)\s*=\s*([^;]+);"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: line.utf16.count)
        
        guard let match = regex?.firstMatch(in: line, range: range),
              let keyRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        
        let key = String(line[keyRange])
        let valueString = String(line[valueRange]).trimmingCharacters(in: .whitespaces)
        
        let commentPattern = #"//\s*(.+)$"#
        let commentRegex = try? NSRegularExpression(pattern: commentPattern)
        let comment = commentRegex?.firstMatch(in: line, range: range).flatMap { match in
            Range(match.range(at: 1), in: line).map { String(line[$0]) }
        }
        
        let type: ServiceSetting.SettingType
        let cleanValue: String
        
        if valueString.hasPrefix("\"") && valueString.hasSuffix("\"") {
            type = .string
            cleanValue = String(valueString.dropFirst().dropLast())
        } else if valueString.lowercased() == "true" || valueString.lowercased() == "false" {
            type = .bool
            cleanValue = valueString.lowercased()
        } else if valueString.contains(".") {
            type = .float
            cleanValue = valueString
        } else if Int(valueString) != nil {
            type = .int
            cleanValue = valueString
        } else {
            type = .string
            cleanValue = valueString
        }
        
        return ServiceSetting(key: key, value: cleanValue, type: type, comment: comment)
    }
    
    private func updateSettingsInJS(_ jsContent: String, with settings: [ServiceSetting]) -> String {
        var lines = jsContent.components(separatedBy: .newlines)
        var inSettingsSection = false
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("// Settings start") {
                inSettingsSection = true
                continue
            }
            
            if trimmedLine.contains("// Settings end") {
                break
            }
            
            if inSettingsSection && trimmedLine.hasPrefix("const ") {
                let pattern = #"const\s+(\w+)\s*=\s*([^;]+);"#
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: trimmedLine.utf16.count)
                
                if let match = regex?.firstMatch(in: trimmedLine, range: range),
                   let keyRange = Range(match.range(at: 1), in: trimmedLine) {
                    let key = String(trimmedLine[keyRange])
                    
                    if let setting = settings.first(where: { $0.key == key }) {
                        let formattedValue: String
                        switch setting.type {
                        case .string:
                            formattedValue = "\"\(setting.value)\""
                        case .bool, .int, .float:
                            formattedValue = setting.value
                        }
                        
                        let commentPart = setting.comment.map { " // \($0)" } ?? ""
                        let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                        lines[index] = "\(leadingWhitespace)const \(setting.key) = \(formattedValue);\(commentPart)"
                    }
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Service Errors

enum ServiceError: LocalizedError {
    case invalidURL
    case invalidScriptURL
    case downloadFailed
    case scriptDownloadFailed
    case invalidJSON
    case invalidScriptContent
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidScriptURL:
            return "Invalid script URL in metadata"
        case .downloadFailed:
            return "Failed to download metadata"
        case .scriptDownloadFailed:
            return "Failed to download JavaScript file"
        case .invalidJSON:
            return "Invalid JSON format"
        case .invalidScriptContent:
            return "Invalid JavaScript content"
        case .saveFailed:
            return "Failed to save service files"
        }
    }
}
