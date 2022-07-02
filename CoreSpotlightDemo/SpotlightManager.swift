//
//  SpotlightManager.swift
//  CoreSpotlightDemo
//
//  Created by FanYu on 2022/7/1.
//

import Foundation
import CoreSpotlight
import MobileCoreServices

struct Model {
    let name: String
    let description: String
}

class SpotlightManager: NSObject {
    
    // Using client state for asynchronous updates
    private enum State {
        static let none = Data([0x00])
        static let finished = Data([0x01])
    }
    
    static let shared = SpotlightManager()
    
    private let queue = DispatchQueue(label: "spotlight")
    
    // Index state uses a named index instance, Create multiple instances if you have more than one data source
    private let index = CSSearchableIndex(name: "spotlight")

    private let mockModels: [Model] = [
        .init(name: "1", description: "this is 1"),
        .init(name: "2", description: "this is 2"),
        .init(name: "3", description: "this is 3"),
        .init(name: "4", description: "this is 4"),
        .init(name: "5", description: "this is 5"),
    ]
    
    override init() {
        super.init()
        index.indexDelegate = self
    }
    
    func contiune(activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        // do some thing
        print(identifier)
    }
    
    func indexIfNeeded() {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }
        queue.async {
            self.index.fetchLastClientState { data, error in
                if let error = error {
                    print(error)
                } else if data != State.finished {
                    self.reindexSearchableItems()
                }
            }
        }
    }
    
    // ❗️Warning: Item count limit is 32767 when 'indexSearchableItems'
    func addSearchableItems(_ items: [CSSearchableItem]) {
        queue.async {
            self.index.beginBatch()
            self.index.indexSearchableItems(items)
            self.index.endBatch(withClientState: State.finished) { error in
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    func deleteAllIndexedItems() {
        queue.async {
            self.index.beginBatch()
            self.index.deleteAllSearchableItems()
            self.index.endBatch(withClientState: State.none) { error in
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    func deleteSearchableItems(_ identifiers: [String]) {
        queue.async {
            self.index.beginBatch()
            self.index.deleteSearchableItems(withIdentifiers: identifiers)
            self.index.endBatch(withClientState: State.finished) { error in
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    func reindexSearchableItems(identifiers: [String]? = nil) {
        let models: [Model]
        if let identifiers = identifiers, !identifiers.isEmpty {
            models = self.mockModels.filter { identifiers.contains($0.name) }
        } else {
            models = self.mockModels
        }
        let items = models.map(self.searchableItem(model:))
        addSearchableItems(items)
    }
    
}

extension SpotlightManager: CSSearchableIndexDelegate {
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        reindexSearchableItems()
        acknowledgementHandler()
    }
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        reindexSearchableItems(identifiers: identifiers)
        acknowledgementHandler()
    }
    
}

extension SpotlightManager {
    
    private func searchableItem(model: Model) -> CSSearchableItem {
        let attributes: CSSearchableItemAttributeSet
        if #available(iOS 14.0, *) {
            attributes = CSSearchableItemAttributeSet(contentType: .text)
        } else {
            attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        }
        attributes.title = model.name
        attributes.keywords = [model.name]
        attributes.contentDescription = model.description
        return CSSearchableItem(uniqueIdentifier: model.name, domainIdentifier: "item", attributeSet: attributes)
    }
    
}

