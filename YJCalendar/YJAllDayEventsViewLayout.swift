//
//  YJAllDayEventsViewLayout.swift
//  YJCalendar
//
//  Created by YoonJu-ho on 2016. 1. 10..
//  Copyright © 2016년 Yoon Ju-ho. All rights reserved.
//

import UIKit

let MoreEventsViewKin = "MoreEventsViewKind"

enum AllDayEventInset: Int {
    case None = 0
    case Left = 1
    case Right = 2
}

protocol YJAllDayEventsViewLayoutDelegate: UICollectionViewDelegate{
    func dayRangeForEvent(collectionView:UICollectionView, layout:YJAllDayEventsViewLayout, indexPath:NSIndexPath)->NSRange
    func visibleDayRange(collectionView:UICollectionView, layout:YJAllDayEventsViewLayout)->NSRange
    func insetsForEvent(collectionView:UICollectionView, layout:YJAllDayEventsViewLayout, indexPath:NSIndexPath)->AllDayEventInset
}

class YJAllDayEventsViewLayout:UICollectionViewLayout {
    //here are my code
    var delegate: YJAllDayEventsViewLayoutDelegate!
    var dayColumnWidth: CGFloat = 0.0       // width of columns
    var eventCellHeight: CGFloat = 0.0      // height of an event cell
    var maxContentHeight: CGFloat = 0.0     // if the total content height, defined by the sum of the height of all stacked cells, is more than this value, then some cells will be hidden and a view at the bottom will indicate the number of hidden events
    
    let kCellSpacing: CGFloat = 2.0      // space around cells
    let kCellInset: CGFloat = 4.0
    
    var maxEventsInSections: Int
    var eventsCount: NSMutableDictionary?        // cache of events count per day [ { day : count }, ... ]
    var hiddenCount: NSMutableDictionary?        // cache of hidden events count per day
    var layoutInfos: NSMutableDictionary?
    var visibleSections: NSRange

    override init() {
        super.init()
        dayColumnWidth = 60.0
        eventCellHeight = 20.0
        maxContentHeight = CGFloat.max
        visibleSections = NSRange.init(location: 0, length: 0)
        
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // maximum number of event lines that can be displayed
    func maxVisibleLines() -> Int {
        return Int((self.maxContentHeight + kCellSpacing + 1) / (self.eventCellHeight + kCellSpacing))
        
    }
    
    // returns the number of event lines displayed for this day range
    func maxVisibleLinesForDaysInRange(range:NSRange) -> Int {
        var count = 0
        for var day = range.location; day < NSMaxRange(range); day++ {
            count = max(count, self.numberOfEventsForDayAtIndex(day))
        }
        // if count < max, we have to keep one row to slow "x more events"
        return count > self.maxVisibleLines() ? self.maxVisibleLines() - 1 : count
    }
    
    func numberOfEventsForDayAtIndex(day:Int) -> Int {
        var count: NSNumber = self.eventsCount!.objectForKey(NSNumber(integer: day)) as! NSNumber
        
        if (count.boolValue) {
            count = NSNumber(integer: (self.collectionView?.numberOfItemsInSection(day))!)
            if (self.eventsCount != nil) {
                self.eventsCount = NSMutableDictionary(capacity: (self.collectionView?.numberOfSections())!)
            }
            self.eventsCount!.setObject(count, forKey: day)
        }
        return count.integerValue
    }
    
    func addHiddenEventForDayAtIndex(day:Int){
        if (self.hiddenCount != nil){
            self.hiddenCount = NSMutableDictionary(capacity: (self.collectionView?.numberOfSections())!)
        }
        var count = self.hiddenCount?.objectForKey(day)?.integerValue
        count = count! + 1
        self.hiddenCount?.setObject(NSNumber(integer: count!), forKey: NSNumber(integer: day))
    }
    
    func numberOfHiddenEventsInSection(section:Int) -> Int{
        return self.hiddenCount?.objectForKey(NSNumber(integer: section)) as! Int
    }
    
    //return a dictionary of (indexPath : range) for all visible events
    func eventRanges() -> NSDictionary {
        var eventRanges: NSMutableDictionary = NSMutableDictionary()
        var visibleSecitons: NSRange = self.delegate.visibleDayRange(self.collectionView!, layout: self)
        
        var previousDaysWithEvents: Bool = false
        for (var day = visibleSecitons.location; day < NSMaxRange(visibleSections); day++){
            var eventsCount = self.numberOfEventsForDayAtIndex(day)
            for (var item = 0; item < eventsCount; item++){
                var path = NSIndexPath(forItem: item, inSection: day)
                var eventRange:NSRange = self.delegate.dayRangeForEvent(collectionView!, layout: self, indexPath: path)
                // keep only those events starting at current column,
                // or those started earlier if this is the first day of the row range
                if (eventRange.location == day || day == visibleSections.location || previousDaysWithEvents){
                    eventRange = NSIntersectionRange(eventRange, visibleSections)
                    eventRanges.setObject(NSValue(range: eventRange), forKey: path)
                }
            }
            if (eventsCount > 0){
                previousDaysWithEvents = true
            }
        }
        return eventRanges
    }
    
    func rectForCellWithRange(range:NSRange, line:Int, insets:AllDayEventInset)->CGRect{
        var x = CGFloat(Int(self.dayColumnWidth) * Int(range.location))
        let y = CGFloat(Int(line) * Int(self.eventCellHeight + kCellSpacing))
        
        if (insets == .Left) {
            x += kCellInset
        }
        
        var width = CGFloat(Int(self.dayColumnWidth) * Int(range.length))
        if (insets == .Right){
            width -= kCellInset
        }
        let rect = CGRectMake(x, y, width, self.eventCellHeight)
        return CGRectInset(rect, kCellSpacing, 0)
    }
    
    //MARK: - UICollectionViewLayout
    override func prepareLayout() {
        self.maxEventsInSections = 0
        self.eventsCount = nil
        self.hiddenCount = nil
        self.layoutInfos = NSMutableDictionary()
        
        var cellInfos = NSMutableDictionary()
        var moreInfos = NSMutableDictionary()
        
        var eventRanges = self.eventRanges()
        var lines = NSMutableArray()
        
        for var indexPath in (eventRanges.allKeys as NSArray).sortedArrayUsingSelector(Selector("compare")){
            var eventRange: NSRange = eventRanges.objectForKey(indexPath)!.rangeValue
            var numLine: Int = 0
            
            for indexes in lines{
                var temp = indexes.intersectsIndexesInRange(eventRange)
                // we found the right line
                if(temp != true){
                    indexes.addIndexesInRange(eventRange)
                    break
                }
                numLine++
            }
            if (numLine == lines.count){
                // this means no line was yet created, or the event does not fit any
                lines.addObject(NSMutableIndexSet(indexesInRange: eventRange))
            }
            
            var maxVisibleEvents = self.maxVisibleLinesForDaysInRange(eventRange)
            if (numLine < maxVisibleEvents){
                let attribs: UICollectionViewLayoutAttributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath as! NSIndexPath)
                
                var insets: AllDayEventInset = AllDayEventInset.None
                if (self.delegate.respondsToSelector(Selector("insetsForEvent:layout:indexPath:"))){
                    insets = self.delegate.insetsForEvent(self.collectionView!, layout: self, indexPath: indexPath as! NSIndexPath)
                }
                var frame: CGRect = rectForCellWithRange(eventRange, line: numLine, insets: insets)
                attribs.frame = frame
                
                cellInfos.setObject(attribs, forKey: indexPath as! NSIndexPath)
                self.maxEventsInSections = max(self.maxEventsInSections, numLine + 1)

            } else {
                for (var day:Int = eventRange.location; day < NSMaxRange(eventRange); day++){
                    self.addHiddenEventForDayAtIndex(day)
                    self.maxEventsInSections = maxVisibleEvents + 1
                }
            }
        }
        var numSections = self.collectionView?.numberOfSections()
        for (var day = 0; day < numSections; day++){
            var hiddenCount = self.numberOfHiddenEventsInSection(day)
            if(hiddenCount>0){
                var path:NSIndexPath = NSIndexPath(forItem: 0, inSection: day)
                var attribs: UICollectionViewLayoutAttributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind:"MoreEventsViewKind" , withIndexPath: path)
                var frame: CGRect = self.rectForCellWithRange(NSMakeRange(day, 1), line: self.maxVisibleLines() - 1, insets: AllDayEventInset.None)
                attribs.frame = frame
                moreInfos.setObject(attribs, forKey: path)
            }
        }
        self.layoutInfos?.setObject(cellInfos, forKey: "cellInfos")
        self.layoutInfos?.setObject(moreInfos, forKey: "moreInfos")
    }
    
    override func collectionViewContentSize() -> CGSize {
        var width = CGFloat((self.collectionView?.numberOfSections())!) * self.dayColumnWidth
        var height = CGFloat(self.maxEventsInSections) * self.eventCellHeight + kCellSpacing
        return CGSizeMake(width, height)
    }
    
}