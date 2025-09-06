//
//  Services.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import Foundation

struct ServicesMetadata: Codable, Hashable {
    let sourceName: String
    let author: Author
    let iconUrl: String
    let version: String
    let language: String
    let baseUrl: String
    let streamType: String
    let quality: String
    let searchBaseUrl: String
    let scriptUrl: String
    let softsub: Bool?
    let multiStream: Bool?
    let multiSubs: Bool?
    let type: String?
    let novel: Bool?
    let settings: Bool?

    struct Author: Codable, Hashable {
        let name: String
        let icon: String
    }
}

struct Services: Codable, Identifiable, Hashable {
    let id: UUID
    let metadata: ServicesMetadata
    let localPath: String
    let metadataUrl: String
    var isActive: Bool
    
    init(id: UUID = UUID(), metadata: ServicesMetadata, localPath: String, metadataUrl: String, isActive: Bool = false) {
        self.id = id
        self.metadata = metadata
        self.localPath = localPath
        self.metadataUrl = metadataUrl
        self.isActive = isActive
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Services, rhs: Services) -> Bool {
        lhs.id == rhs.id
    }
}
