//
//  Timer.swift
//  Timer
//
//  Created by Wallace Maia Campos on 11/10/15.
//  Copyright © 2015 Wallace Maia Campos. All rights reserved.
//

import Foundation

/**
 
 A protocol that groups methods and properties for objects that wants to fire and handle time events.
 
 */
public protocol TimerManagerType {
  
  /// The gap between executions in seconds.
  var interval: Double { get }
  
  /// Current timer time.
  var time: Double { get }
  
  /// Whether the timer is in paused state or not.
  var paused: Bool { get }
  
  /// A closure to handle the resume event. It must receive a time parameter as time passes.
  /// Time must be in seconds.
  var resumeHandler: ((Double) -> ())? { get set }
  
  /// A closure to handle the pause event. It must receive a time parameter as seconds.
  var pauseHandler: ((Double) -> ())? { get set }
  
  /// A closure to handle the cancel event.
  var cancelHandler: (() -> ())? { get set }
  
  
  /**
    
    Initialize and returns a new timer manager object with the specified interval, initial time and whether the timer repeats or not.
    
    - Parameters:
      - interval: The gap between timer execution.
      - time: Timer initial time.
      - repeats: Whether the timer calls must repeat or not.
   
    - Returns: An initialized timer manager object or `nil` if the object couldn't be created.
   
   */
  init?(interval: Double, time: Double, repeats: Bool)
  
  
  /// Resume the timer.
  func resume()
  
  /// Cancel the timer.
  func cancel()
  
  /// Pause the timer.
  func pause()
  
}

/**
 
  A default `TimerManagerType` protocol implementation.
  This implementation uses Grand Central Dispatch and run in a concurrent global queue.
 
*/

public class TimerManager: TimerManagerType {
  
  private var timer: dispatch_source_t?
  private var pausedTime: Double = 0
  private var repeats: Bool
  
  public private(set) var interval: Double
  
  public private(set) var time: Double
  
  public private(set) var paused: Bool = false
  
  public var resumeHandler: ((Double) -> ())?
  
  public var pauseHandler: ((Double) -> ())?
  
  public var cancelHandler: (() -> ())?
  
  public required init?(interval: Double, time: Double, repeats: Bool) {
    
    self.repeats = repeats
    self.interval = interval
    self.time = time
    
    if repeats {
      
      timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
      
      
      if timer == nil {
        return nil
      }
      
      dispatch_source_set_timer(timer!,
        dispatch_time(DISPATCH_TIME_NOW, Int64(abs(interval) * Double(NSEC_PER_SEC))),
        UInt64(abs(interval) * Double(NSEC_PER_SEC)),
        NSEC_PER_SEC / 100)
      
      dispatch_source_set_event_handler(timer!) { [weak self] in
        
        self?.eventHandler()
      }
      
      dispatch_source_set_cancel_handler(timer!) {
        dispatch_sync(dispatch_get_main_queue()) { [weak self] in
          self?.cancelHandler?()
        }
      }
      
    }
  }
  
  deinit {
    self.cancel()
  }
  
  private func eventHandler() {
    
    dispatch_async(dispatch_get_main_queue()) { [weak self] in
      
      if self != nil {
        
        if !self!.paused {
          self!.time += self!.interval
          self!.resumeHandler?(self!.time)
          
        } else {
          self!.pausedTime += self!.interval
          self!.pauseHandler?(self!.pausedTime)
          
        }
      }
    }
  }
  
  public func resume() {
    if !repeats {
      
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(interval * Double(NSEC_PER_SEC))), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        
        dispatch_async(dispatch_get_main_queue()) {
          self.time += self.interval
          
          self.resumeHandler?(self.time)
        }
      }
    } else if timer != nil {
      
      if paused {
        dispatch_suspend(self.timer!)
        paused = false
        pausedTime = 0
      }
      dispatch_resume(self.timer!)
    }
  }
  
  public func cancel() {
    
    if timer != nil {
      dispatch_source_cancel(timer!)
    }
  }
  
  public func pause() {
    paused = true
  }
}

/**
 
  The `Timer` class defines a timer that counts according to the interval parameter sign.
  Positive interval counts up and negative intervals counts down. It should be clear that when counting down, below zero time, the timer will receive negative value updates and it will not stop until it's explicitly stopped.
  
  Example of use:
  ````
  let timer = Timer(initial: 0)
 
  timer.tick(every: 1) {
    print($0)
    if $0 == 10 {
      timer.stop()
    }
  }
  ````
 
  - note:
  Use _closure capture list_ to break strong references cycles when referencing `self`.
  
  ````
  let timer = Timer(initial: 10)
 
  timer.tick(every: 2) { [unowned self] in
    self.doSomething($0)
  }
  ````
*/

public class Timer {
  
  private var manager: TimerManagerType?
  
  /// Current timer time.
  private(set) var time: Double
  
  /// The gap between executions in seconds.
  private(set) var interval: Double = 0
  
  /// Whether the timer is in paused state or not.
  private(set) var paused: Bool = false
  
  /**
   
    The timer manager to use. On subclassing, override this property
    to use another manager. It __must__ conforms to `TimerManagerType` protocol.
   
   */
  class var Manager: TimerManagerType.Type {
    return TimerManager.self
  }
  
  /**
   
    The timer executes once.
   
    - Parameters:
      - interval: The delay of execution in seconds.
      - update: A closure to handle the timer call.
   */
  class func once(after interval: Double = 1.0, _ update: () -> ()) {
    
    var manager = Manager.init(interval: interval, time: 0, repeats: false)
    manager?.resumeHandler = { _ in update() }
    manager?.resume()
  }
  
  /**
   
    Create a new timer from a starting time.
   
    - Parameters:
      - time: The timer starting time. Defaults to `0`
   
    - Returns: An initialized timer ready to be used.
   
   */
  init(initial time: Double = 0.0) {
    
    self.time = time
  }
  
  /**
   
    The timer start counting up forever until you stop it.
   
    - Parameters:
      - interval: The gap between executions in seconds.
      - update: A closure to handle each timer call.
   
   */
  func tick(every interval: Double = 1.0, _ update: (Double) -> ()) {
    self.interval = interval
    
    manager = self.dynamicType.Manager.init(interval: interval, time: self.time, repeats: true)
    manager?.resumeHandler = update
    manager?.resume()
  }
  
  /**
   
    Pause the timer.
   
    - Parameters:
      - time: The time to remain paused in seconds. When time is `0`, the timer pause indefinitely. Defaults to `0`.
      - update: A closure to handle each call. It receives the time paused as a parameter. It's optional and defaults to `nil`.
   
   */
  func pause(during time: Double = 0, _ update: ((Double) -> ())? = nil) {
    
    if update != nil {
      manager?.pauseHandler = { [weak self] in
        if time == $0 && time != 0 {
          self?.resume()
        }
        update?($0)
      }
    }
    manager?.pause()
    paused = true
  }
  
  /// Resume the timer after pause it.
  func resume() {
    paused = false
    manager?.resume()
  }
  
  /// Stop the timer.
  func stop() {
    manager?.cancel()
  }
}

/**
 
 The `Countdown` timer start counting down and stops when it reaches `0`.
 
 ````
 let countdown = Countdown(initial: 60)
 
 countdown.tick(every: 1) {
   print($0)
   if $0 == 10 {
     timer.pause(during: 10) {
 
     }
   }
 }
 ````
 
 */
public class Countdown: Timer {
  
  override func tick(every interval: Double, _ update: (Double) -> ()) {
    let interval = interval > 0 ? -interval : interval
    
    if time == 0 {
      return
    }
    
    super.tick(every: interval) {
      
      if $0 <= 0 {
        super.stop()
      }
      update($0)
    }
  }
}