//
//  AltMarketplace.swift
//  AltMarketplace
//
//  Created by Riley Testut on 1/26/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation
import ExtensionFoundation
import MarketplaceKit

import AltStoreCore

@main
final class AltMarketplace: MarketplaceExtension
{
    required init()
    {
        // Hacky, but reliable.
        let semaphore = DispatchSemaphore(value: 0)
        
        DatabaseManager.shared.start { error in
            semaphore.signal()
            
            if let error
            {
                fatalError("Failed to load database: \(error.localizedDescription)")
            }
        }
        
        _ = semaphore.wait(timeout: .now())
    }
    
    func additionalHeaders(for request: URLRequest, account: String) -> [String : String]?
    {
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1"
        var additionalHeaders = ["ALT_PAL_VER": bundleVersion]
        
        guard let requestURL = request.url, requestURL.path().contains("restore") || requestURL.path().contains("update") else { return additionalHeaders }
        
        do
        {
            guard let data = request.httpBody else { throw URLError(URLError.Code.unsupportedURL) }
            
            let payload = try Foundation.JSONDecoder().decode(InstallAppRequest.self, from: data)
            
            for app in payload.apps
            {
                guard let marketplaceID = AppleItemID(app.appleItemId) else { continue }
                        
                let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
                
                let values = context.performAndWait { () -> (bundleID: String, adpURL: URL, version: String, buildVersion: String)? in
                    //TODO: Somehow determine which source to use if there are multiple.
                    let predicate = NSPredicate(format: "%K == %@", #keyPath(StoreApp._marketplaceID), marketplaceID.description)
                    guard let storeApp = StoreApp.first(satisfying: predicate, in: context) else { return nil }
                    
                    let installedAppVersion = storeApp.installedApp?.version ?? storeApp.latestSupportedVersion?.version
                    
                    // Return values
                    guard let appVersion = storeApp.versions.first(where: { $0.version == installedAppVersion }), let buildVersion = appVersion.buildVersion else { return nil }
                    return (storeApp.bundleIdentifier, appVersion.downloadURL, appVersion.version, buildVersion)
                }
                
                if let values
                {
                    let bundleID = HTTPHeader.bundleID(for: marketplaceID)
                    let adpHeader = HTTPHeader.adpURL(for: marketplaceID)
                    let versionHeader = HTTPHeader.version(for: marketplaceID)
                    let buildVersionHeader = HTTPHeader.buildVersion(for: marketplaceID)
                    
                    additionalHeaders[bundleID.rawValue] = values.bundleID
                    additionalHeaders[adpHeader.rawValue] = values.adpURL.absoluteString
                    additionalHeaders[versionHeader.rawValue] = values.version
                    additionalHeaders[buildVersionHeader.rawValue] = values.buildVersion
                }
            }
        }
        catch
        {
            Logger.main.error("Failed to provide additional headers for request \(request, privacy: .public). \(error.localizedDescription, privacy: .public)")
        }
        
        return additionalHeaders
    }
    
    func availableAppVersions(forAppleItemIDs ids: [AppleItemID]) -> [MarketplaceKit.AppVersion]?
    {
        return []
    }
    
    func requestFailed(with response: HTTPURLResponse) -> Bool
    {
        return false
    }
    
    func automaticUpdates(for installedAppVersions: [MarketplaceKit.AppVersion]) async throws -> [AutomaticUpdate]
    {
        return []
    }
}
