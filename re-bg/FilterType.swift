//
//  FilterType.swift
//  re-bg
//
//  Created by Photo Editor
//

import Foundation

enum FilterType: String, CaseIterable, Identifiable {
    case none = "Original"
    case losAngeles = "Los Angeles"
    case paris = "Paris"
    case tokyo = "Tokyo"
    case london = "London"
    case newYork = "New York"
    case milan = "Milan"
    case sepia = "Antique"
    case dramatic = "Studio"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue
    }
}
