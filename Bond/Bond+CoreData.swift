//
//  Bond+CoreData.swift
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

#if os(iOS)

import Foundation
import CoreData

extension NSFetchedResultsController {
  public func results<T : NSManagedObject>(type: T.Type, loadData: Bool = true) -> FetchedResultsArray<T> {
    return FetchedResultsArray(frc: self, type: type, loadData: loadData)
  }
}

public class FetchedResultsArray<T> : DynamicArray<T> {
  
  let frcDelegate = FetchedResultsControllerDynamicDelegate()
  var frc: NSFetchedResultsController
  
  public init(frc: NSFetchedResultsController, type: T.Type, loadData: Bool = true) {
    self.frc = frc
    super.init(Array<T>())
    frcDelegate.dispatcher = self
    if loadData {
      reloadData()
    }
  }
  
  public func reloadData() {
    if frc.fetchedObjects == nil {
      frcDelegate.nextDelegate = frc.delegate
      frc.delegate = frcDelegate
      var error: NSError?
      dispatchWillReset()
      if !frc.performFetch(&error) {
        println("***** Error fetching \(frc.fetchRequest) \(error) *****")
      }
      dispatchDidReset()
    } else {
      // TODO: no-op for now, consider niling out frc and refetch completely
    }
  }
  
  // For some reason this private helper is needed to avoid crash
  private func objects() -> [T] {
    if let objects = frc.fetchedObjects {
      return objects.map { $0 as! T }
    }
    return []
  }
  
  override public var value: [T] {
    get { return objects() }
    set(newValue) { fatalError("Modifying fetched results array is not supported!") }
  }
  
  override public var count: Int {
    return frc.fetchedObjects?.count ?? 0
  }
  
  override public subscript(index: Int) -> T {
    get { return objects()[index] }
    set { fatalError("Modifying fetched results array is not supported!") }
  }
  
  override public func setArray(newValue: [T]) {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func append(newElement: T) {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func append(array: Array<T>) {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func removeLast() -> T {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func insert(newElement: T, atIndex i: Int) {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func splice(array: Array<T>, atIndex i: Int) {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func removeAtIndex(index: Int) -> T {
    fatalError("Modifying fetched results array is not supported!")
  }
  
  override public func removeAll(keepCapacity: Bool) {
    fatalError("Modifying fetched results array is not supported!")
  }
}

extension FetchedResultsArray : FetchedResultsDispatcher {
  func dispatchDidChangeCount(newCount: Int) {
    dynCount.value = newCount
  }
}

protocol FetchedResultsDispatcher : class {
  func dispatchWillInsert(indices: [Int])
  func dispatchDidInsert(indices: [Int])
  func dispatchWillRemove(indices: [Int])
  func dispatchDidRemove(indices: [Int])
  func dispatchWillUpdate(indices: [Int])
  func dispatchDidUpdate(indices: [Int])
  func dispatchWillPerformBatchUpdates()
  func dispatchDidPerformBatchUpdates()
  func dispatchDidChangeCount(newCount: Int)
}

@objc class FetchedResultsControllerDynamicDelegate : NSObject {
  weak var dispatcher: FetchedResultsDispatcher?
  @objc weak var nextDelegate: NSFetchedResultsControllerDelegate?
}

extension FetchedResultsControllerDynamicDelegate : NSFetchedResultsControllerDelegate {
  
  func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
    assert(NSThread.isMainThread(), "Should only happen on main thread")
    switch type {
    case .Insert:
      dispatcher?.dispatchWillInsert([newIndexPath!.row])
      dispatcher?.dispatchDidInsert([newIndexPath!.row])
    case .Delete:
      dispatcher?.dispatchWillRemove([indexPath!.row])
      dispatcher?.dispatchDidRemove([indexPath!.row])
    case .Update:
      dispatcher?.dispatchWillUpdate([indexPath!.row])
      dispatcher?.dispatchDidUpdate([indexPath!.row])
    case .Move:
      // TODO: Native move implementation?
      dispatcher?.dispatchWillRemove([indexPath!.row])
      dispatcher?.dispatchWillInsert([newIndexPath!.row])
      dispatcher?.dispatchDidInsert([newIndexPath!.row])
      dispatcher?.dispatchDidRemove([indexPath!.row])
    }
    nextDelegate?.controller?(controller, didChangeObject: anObject, atIndexPath: indexPath, forChangeType: type, newIndexPath: newIndexPath)
  }
  
  func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    fatalError("Fetched Results with sections is not yet supported. Please add pull request :)")
  }
  
  func controllerWillChangeContent(controller: NSFetchedResultsController) {
    dispatcher?.dispatchWillPerformBatchUpdates()
    nextDelegate?.controllerWillChangeContent?(controller)
  }
  
  func controller(controller: NSFetchedResultsController, sectionIndexTitleForSectionName sectionName: String?) -> String? {
    return nextDelegate?.controller?(controller, sectionIndexTitleForSectionName: sectionName)
  }
  
  func controllerDidChangeContent(controller: NSFetchedResultsController) {
    assert(NSThread.isMainThread(), "Has to run on main")
    dispatcher?.dispatchDidChangeCount(controller.fetchedObjects?.count ?? 0)
    dispatcher?.dispatchDidPerformBatchUpdates()
    nextDelegate?.controllerDidChangeContent?(controller)
    for (index, object) in enumerate(controller.fetchedObjects!) {
    }
  }
}

#endif
