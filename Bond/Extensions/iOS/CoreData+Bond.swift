//
//  CoreData+Bond.swift
//  Bond
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Srdan Rasic (@srdanrasic)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import CoreData

extension NSFetchedResultsController {
  public func results<T : NSManagedObject>(type: T.Type, loadData: Bool = true) -> FetchedResultsArray<T> {
    return FetchedResultsArray(frc: self, type: type, loadData: loadData)
  }
}

public class FetchedResultsArray<ElementType> : EventProducer<ObservableArrayEvent<Array<ElementType>>>, ObservableArrayType {
  
  var batchedOperations: [ObservableArrayOperation<ElementType>] = []
  let frcDelegate = FetchedResultsControllerDynamicDelegate()
  public let frc: NSFetchedResultsController
  public let predicate: Observable<NSPredicate?>
  
  public init(frc: NSFetchedResultsController, type: ElementType.Type, loadData: Bool = true) {
    self.frc = frc
    self.predicate = Observable(frc.fetchRequest.predicate)
    super.init(replayLength: 1)
    predicate.observeNew { [weak self] pred in
        self?.frc.fetchRequest.predicate = pred
        self?.reloadData()
    }
    frcDelegate.dispatcher = self
    frcDelegate.nextDelegate = frc.delegate
    frc.delegate = frcDelegate
    if loadData {
      reloadData()
    }
  }
  
  deinit {
    frc.delegate = nil // frc.delegate is unowned, important to set to nil
  }
  
  /// Invoke performFetch through FetchedResultsArray instead of frc to get change notifications
  public func reloadData() {
    NSFetchedResultsController.deleteCacheWithName(frc.cacheName)
    do {
      try frc.performFetch()
    } catch {
      print("***** Error fetching \(frc.fetchRequest) \(error) *****")
    }
    let newValue = array
    next(ObservableArrayEvent(sequence: newValue, operation: .Reset(array: newValue)))
  }
  
  public var array: [ElementType] {
    if let objects = frc.fetchedObjects {
      return objects.map { $0 as! ElementType }
    }
    return []
  }

  public var count: Int {
    return frc.fetchedObjects?.count ?? 0
  }
  
  public subscript(index: Int) -> ElementType {
    get { return array[index] }
    set { fatalError("Modifying fetched results array is not supported!") }
  }
}

extension FetchedResultsArray : FetchedResultsDispatcher {
  func dispatchDidInsert(index: Int) {
    batchedOperations.append(.Insert(elements: [array[index]], fromIndex: index))
  }
  func dispatchDidRemove(index: Int) {
    let range = index-1..<index
    batchedOperations.append(.Remove(range: range))
  }
  func dispatchDidUpdate(index: Int) {
    batchedOperations.append(.Update(elements: [array[index]], fromIndex: index))
  }
  func dispatchWillPerformBatchUpdates() {
    // Noop
  }
  func dispatchDidPerformBatchUpdates() {
    next(ObservableArrayEvent(sequence: array, operation: .Batch(batchedOperations)))
  }
  func dispatchDidChangeCount(newCount: Int) {
    // Noop for now
  }
}

// MARK: - FetchedResultsControllerDynamicDelegate

protocol FetchedResultsDispatcher : class {
  func dispatchDidInsert(index: Int)
  func dispatchDidRemove(index: Int)
  func dispatchDidUpdate(index: Int)
  func dispatchWillPerformBatchUpdates()
  func dispatchDidPerformBatchUpdates()
  func dispatchDidChangeCount(newCount: Int)
}

@objc class FetchedResultsControllerDynamicDelegate : NSObject {
  weak var dispatcher: FetchedResultsDispatcher?
  @objc weak var nextDelegate: NSFetchedResultsControllerDelegate?
}

extension FetchedResultsControllerDynamicDelegate : NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(controller: NSFetchedResultsController) {
    dispatcher?.dispatchWillPerformBatchUpdates()
    nextDelegate?.controllerWillChangeContent?(controller)
  }
  
  func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    nextDelegate?.controller?(controller, didChangeSection: sectionInfo, atIndex: sectionIndex, forChangeType: type)
    print("WARNING: Fetched Results with sections is not yet supported. Please add pull request :)")
  }
  
  func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
    assert(NSThread.isMainThread(), "Should only happen on main thread")
    switch type {
    case .Insert:
      dispatcher?.dispatchDidInsert(newIndexPath!.row)
    case .Delete:
      dispatcher?.dispatchDidRemove(indexPath!.row)
    case .Update:
      dispatcher?.dispatchDidUpdate(indexPath!.row)
    case .Move:
      // TODO: Native move implementation?
      dispatcher?.dispatchDidInsert(newIndexPath!.row)
      dispatcher?.dispatchDidRemove(indexPath!.row)
    }
    nextDelegate?.controller?(controller, didChangeObject: anObject, atIndexPath: indexPath, forChangeType: type, newIndexPath: newIndexPath)
  }
  
  func controllerDidChangeContent(controller: NSFetchedResultsController) {
    assert(NSThread.isMainThread(), "Has to run on main")
    dispatcher?.dispatchDidChangeCount(controller.fetchedObjects?.count ?? 0)
    dispatcher?.dispatchDidPerformBatchUpdates()
    nextDelegate?.controllerDidChangeContent?(controller)
  }
  
  func controller(controller: NSFetchedResultsController, sectionIndexTitleForSectionName sectionName: String) -> String? {
    return nextDelegate?.controller?(controller, sectionIndexTitleForSectionName: sectionName)
  }
}
