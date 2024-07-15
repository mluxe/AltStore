//
//  URL+ADP.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation

extension URL
{
    static func installURL(for adpURL: URL) -> URL?
    {
        // AWS has trouble parsing URLs with encoded `/`, so we replace them with '|' before encoding.
        // This technically breaks any URLs with '|' in them, but YOLO.
        let encodedADPLink = adpURL.absoluteString.replacingOccurrences(of: "/", with: "|")
        
        var components = URLComponents(string: AppMarketplace.marketplaceDomain, encodingInvalidCharacters: true)!
        components.path += "/install/" + encodedADPLink // Assigning path will implicitly percent-encode it

        let redirectURL = components.url
        return redirectURL
    }
}
