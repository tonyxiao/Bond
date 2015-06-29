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

import Foundation
import CoreData

private var sectionsDynamicHandleNSFetchedResultsController: UInt8 = 0;
private var countDynamicHandleNSFetchedResultsController: UInt8 = 0;
private var delegateDynamicHandleNSFetchedResultsController: UInt8 = 0;

extension NSFetchedResultsController {
    
    public var dynSections: DynamicArray<DynamicArray<NSManagedObject>> {
        if let d: AnyObject = objc_getAssociatedObject(self, &sectionsDynamicHandleNSFetchedResultsController) {
            return (d as? DynamicArray<DynamicArray<NSManagedObject>>)!
        } else {
            var error: NSError?
            if !performFetch(&error) {
                fatalError("Unable to perform fetch for request \(fetchRequest)")
            }
            let d = DynamicArray(sections!.map {
                DynamicArray(($0 as! NSFetchedResultsSectionInfo).objects.map { $0 as! NSManagedObject })
                })
            dynDelegate.sections = d
            if dynDelegate.nextDelegate == nil {
                dynDelegate.nextDelegate = delegate
            }
            delegate = dynDelegate
            objc_setAssociatedObject(self, &sectionsDynamicHandleNSFetchedResultsController, d, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            return d
        }
    }
    
    public var dynCount: Dynamic<Int> {
        if let d: AnyObject = objc_getAssociatedObject(self, &countDynamicHandleNSFetchedResultsController) {
            return (d as? Dynamic<Int>)!
        } else {
            var error: NSError?
            if !performFetch(&error) {
                fatalError("Unable to perform fetch for request \(fetchRequest)")
            }
            let d = Dynamic<Int>(0)
            dynDelegate.count = d
            if dynDelegate.nextDelegate == nil {
                dynDelegate.nextDelegate = delegate
            }
            delegate = dynDelegate
            objc_setAssociatedObject(self, &countDynamicHandleNSFetchedResultsController, d, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            return d
        }
    }
    
    public var nextDelegate: NSFetchedResultsControllerDelegate? {
        get { return dynDelegate.nextDelegate }
        set { dynDelegate.nextDelegate = newValue }
    }
    
    var dynDelegate: FetchedResultsControllerDynamicDelegate {
        if let d: AnyObject = objc_getAssociatedObject(self, &delegateDynamicHandleNSFetchedResultsController) {
            return (d as? FetchedResultsControllerDynamicDelegate)!
        } else {
            let d = FetchedResultsControllerDynamicDelegate()
            objc_setAssociatedObject(self, &delegateDynamicHandleNSFetchedResultsController, d, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            return d
        }
    }
}

@objc class FetchedResultsControllerDynamicDelegate : NSObject {
    weak var sections: DynamicArray<DynamicArray<NSManagedObject>>?
    weak var count: Dynamic<Int>?
    @objc weak var nextDelegate: NSFetchedResultsControllerDelegate?
}

extension FetchedResultsControllerDynamicDelegate : NSFetchedResultsControllerDelegate {
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        assert(NSThread.isMainThread(), "Should only happen on main thread")
        switch type {
        case .Insert:
            println("\(unsafeAddressOf(self)) Will insert object \(anObject.objectID) at index \(newIndexPath)")
//            sections?[newIndexPath!.section].insert(anObject as! NSManagedObject, atIndex: newIndexPath!.row)
        case .Delete:
            println("\(unsafeAddressOf(self)) Will delete object \(anObject.objectID) at index \(indexPath)")
//            sections?[indexPath!.section].removeAtIndex(indexPath!.row)
        case .Update:
            println("\(unsafeAddressOf(self)) Will update object \(anObject.objectID) at index \(indexPath)")
//            sections?[indexPath!.section][indexPath!.row] = anObject as! NSManagedObject
        case .Move:
            println("\(unsafeAddressOf(self)) Will move object \(anObject.objectID) from \(indexPath) to \(newIndexPath)")
//            sections?[indexPath!.section].removeAtIndex(indexPath!.row)
//            sections?[newIndexPath!.section].insert(anObject as! NSManagedObject, atIndex: newIndexPath!.row)
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        assert(NSThread.isMainThread(), "Should only happen on main thread")
        switch type {
        case .Insert:
            sections?.insert(DynamicArray([]), atIndex: sectionIndex)
        case .Delete:
            sections?.removeAtIndex(sectionIndex)
        default:
            fatalError("Received impossible NSFetchedResultsChangeType \(type)")
        }
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        println("Controller will change content")
        nextDelegate?.controllerWillChangeContent?(controller)
    }
    
    func controller(controller: NSFetchedResultsController, sectionIndexTitleForSectionName sectionName: String?) -> String? {
        return nextDelegate?.controller?(controller, sectionIndexTitleForSectionName: sectionName)
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        assert(NSThread.isMainThread(), "Has to run on main")
        count?.value = controller.fetchedObjects?.count ?? 0
        nextDelegate?.controllerDidChangeContent?(controller)
        for (index, object) in enumerate(controller.fetchedObjects!) {
            println("\(index): \((object as! NSManagedObject).objectID)")
        }
        println("Controller did change content")
    }
}
