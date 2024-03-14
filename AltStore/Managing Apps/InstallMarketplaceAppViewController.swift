//
//  InstallMarketplaceAppViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/5/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import UIKit
import MarketplaceKit

import AltStoreCore

import Roxas

extension InstallMarketplaceAppViewController
{
    enum Section: Int
    {
        case header
        case button
    }
    
    class ActionButtonCell: UICollectionViewCell
    {
        var actionButton: ActionButton? {
            didSet {
                guard let actionButton else { return }
                self.contentView.addSubview(actionButton, pinningEdgesWith: .zero)
                
                self.contentView.setNeedsLayout()
            }
        }
                
        override func layoutSubviews() 
        {
            super.layoutSubviews()
            
            if let actionButton
            {
                actionButton.layer.cornerRadius = actionButton.layer.bounds.size.height / 2
                
                self.layer.setNeedsDisplay()
            }
        }
    }
}

@available(iOS 17.4, *)
class InstallMarketplaceAppViewController: UICollectionViewController
{
    let buttonAction: AppBannerView.AppAction!
    
    var completionHandler: ((Result<Void, Error>) -> Void)?
    
    private var actionButton: ActionButton!
    @IBOutlet private var actionButtonContainerView: UIView!
    
    private lazy var dataSource = self.makeDataSource()
    
    init(action: AppBannerView.AppAction)
    {
        self.buttonAction = action
        
        let layout = Self.makeLayout()
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView.isScrollEnabled = false
                
        self.collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        self.collectionView.register(ActionButtonCell.self, forCellWithReuseIdentifier: "ActionButtonCell")
        
        self.collectionView.dataSource = self.dataSource
        
        if case .open = self.buttonAction
        {
            self.title = NSLocalizedString("Confirm Action", comment: "")
        }
        else
        {
            self.title = NSLocalizedString("Confirm Installation", comment: "")
        }
        
        self.view.backgroundColor = .white
        
        self.navigationController?.isModalInPresentation = true
        
        let cancelButton = UIBarButtonItem(systemItem: .cancel)
        cancelButton.target = self
        cancelButton.action = #selector(InstallMarketplaceAppViewController.cancel)
        self.navigationItem.leftBarButtonItem = cancelButton
        
        self.navigationController?.navigationBar.tintColor = .altPrimary
        
        if let sheetController = self.navigationController?.sheetPresentationController
        {
            let customDetent = UISheetPresentationController.Detent.custom { context in
                return 250
            }
            
            sheetController.detents = [customDetent]
            sheetController.selectedDetentIdentifier = .medium
            sheetController.prefersGrabberVisible = true
        }
        
        self.prepareActionButton()
    }
    
    func prepareActionButton()
    {
        var action: ActionButton.Action?
        var tintColor: UIColor?
        var appName: String?
        
        switch self.buttonAction
        {
        case .open(let app):
            guard let storeApp = app.storeApp, let marketplaceID = storeApp.marketplaceID else { break } //TOOD: Should InstalledApp have it's own reference to marketplaceID?
            action = .launch(marketplaceID)
            tintColor = storeApp.tintColor
            appName = storeApp.name
            
        case .install(let storeApp):
            //TODO: How do we handle fallback of downloading older iOS version if we have to pick the not-latest version? Does provided URL not matter?
            // JK, it'll only ever fall back to latestSupportedVersion, so just supply that
            guard let marketplaceID = storeApp.marketplaceID, let downloadURL = storeApp.latestSupportedVersion?.downloadURL else { break }
                     
            let bundleID = storeApp.bundleIdentifier
            tintColor = storeApp.tintColor
            appName = storeApp.name
            
            //TODO: Do accounts matter?
            let config = InstallConfiguration(install: .init(account: "AltStore", appleItemID: marketplaceID, alternativeDistributionPackage: downloadURL, isUpdate: false),
                                              confirmInstall: {
                do
                {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true)
                        self.completionHandler?(.success(()))
                    }
                    
                    let installToken = try await AppMarketplace.shared.requestInstallToken(bundleID: bundleID)
                    return .confirmed(installVerificationToken: installToken, authenticationContext: nil)
                }
                catch
                {
                    await self.completionHandler?(.failure(error))
                    
                    return .cancel
                }
            })
            
            action = .install(config)
            
        case .update(let installedApp):
            guard let storeApp = installedApp.storeApp, let marketplaceID = storeApp.marketplaceID, let downloadURL = storeApp.latestSupportedVersion?.downloadURL else { break }
            
            let bundleID = storeApp.bundleIdentifier
            tintColor = storeApp.tintColor
            appName = storeApp.name
            
            let config = InstallConfiguration(install: .init(account: "AltStore", appleItemID: marketplaceID, alternativeDistributionPackage: downloadURL, isUpdate: true),
                                              confirmInstall: {
                do
                {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true)
                        self.completionHandler?(.success(()))
                    }
                    
                    let installToken = try await AppMarketplace.shared.requestInstallToken(bundleID: bundleID)
                    return .confirmed(installVerificationToken: installToken, authenticationContext: nil)
                }
                catch
                {
                    await self.completionHandler?(.failure(error))
                    
                    return .cancel
                }
            })
            action = .install(config)
            
        case .custom: action = .launch(6478868316) // AltStore's marketplace ID
        case .none: break
        }
        
        guard let action else { return }
        
        let actionName: String
        
        switch self.buttonAction
        {
        case .install: actionName = NSLocalizedString("Install", comment: "")
        case .open: actionName = NSLocalizedString("Open", comment: "")
        case .update: actionName = NSLocalizedString("Update", comment: "")
        case .custom(let title): actionName = title
        case .none: actionName = NSLocalizedString("Install", comment: "")
        }
        
        let buttonTitle = String(format: NSLocalizedString("%@ %@", comment: ""), actionName, appName ?? NSLocalizedString("App", comment: ""))
                
        let actionButton = ActionButton(action: action)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.backgroundColor = tintColor ?? .altPrimary
        actionButton.label = " " + buttonTitle + " "
        actionButton.fontSize = 18
        actionButton.cornerRadius = 15
        actionButton.tintColor = .white
        actionButton.isEnabled = true
        self.actionButton = actionButton
    }
}

@available(iOS 17.4, *)
private extension InstallMarketplaceAppViewController
{
    @objc
    func cancel()
    {
        self.completionHandler?(.failure(CancellationError()))
        
        self.dismiss(animated: true)
    }
    
    func makeDataSource() -> RSTDynamicCollectionViewDataSource<UIImage>
    {
        let dataSource = RSTDynamicCollectionViewDataSource<UIImage>()
        dataSource.numberOfItemsHandler = { _ in 1 }
        dataSource.numberOfSectionsHandler = { 2 }
        dataSource.cellIdentifierHandler = { indexPath in
            guard let section = Section(rawValue: indexPath.section) else { return RSTCellContentGenericCellIdentifier }
            switch section
            {
            case .header: return RSTCellContentGenericCellIdentifier
            case .button: return "ActionButtonCell"
            }
        }
        dataSource.cellConfigurationHandler = { (cell, _, indexPath) in
            guard let section = Section(rawValue: indexPath.section) else { return }
            switch section
            {
            case .header:
                let cell = cell as! UICollectionViewListCell
                
                let actionName: String
                let appName: String
                
                switch self.buttonAction
                {
                case .install(let storeApp):
                    actionName = NSLocalizedString("install", comment: "")
                    appName = storeApp.name
                    
                case .open(let installedApp):
                    actionName = NSLocalizedString("open", comment: "")
                    appName = installedApp.name
                    
                case .update(let installedApp):
                    actionName = NSLocalizedString("update", comment: "")
                    appName = installedApp.name
                    
                case .custom(let title): 
                    actionName = title
                    appName = NSLocalizedString("this app", comment: "")
                    
                case .none:
                    actionName = NSLocalizedString("install", comment: "")
                    appName = NSLocalizedString("this app", comment: "")
                }

                let headerText = String(format: NSLocalizedString("Are you sure you'd like to %@ %@?", comment: ""), actionName, appName)
                
                var config = cell.defaultContentConfiguration()
                config.text = headerText
                config.textProperties.font = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title2), size: 0.0)
                config.textProperties.color = .systemGray
                config.textToSecondaryTextVerticalPadding = 5.0
                config.directionalLayoutMargins.top = 20
                config.directionalLayoutMargins.bottom = 20
                config.directionalLayoutMargins.leading = 20
                config.directionalLayoutMargins.trailing = 20
                config.textProperties.alignment = .center
                cell.contentConfiguration = config
                
            case .button:
                let cell = cell as! ActionButtonCell
                cell.actionButton = self.actionButton
            }
        }
        
        return dataSource
    }
    
    class func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let layoutConfig = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfig.interSectionSpacing = 10
        
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
                        
            switch section
            {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = 15
                layoutSection.orthogonalScrollingBehavior = .none
                
                return layoutSection
                
            case .button:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(44))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = 15
                layoutSection.orthogonalScrollingBehavior = .none
                
                return layoutSection
            }
            
        }, configuration: layoutConfig)

        return layout
    }
}

extension InstallMarketplaceAppViewController
{
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool 
    {
        return false
    }
}
