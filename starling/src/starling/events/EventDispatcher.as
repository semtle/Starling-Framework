// =================================================================================================
//
//	Starling Framework
//	Copyright 2011 Gamua OG. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.events
{
    import flash.utils.Dictionary;
    
    import starling.core.starling_internal;
    import starling.display.DisplayObject;
    import starling.utils.Reference;
    
    use namespace starling_internal;
    
    /** The EventDispatcher class is the base class for all classes that dispatch events. 
     *  This is the Starling version of the Flash class with the same name. 
     *  
     *  <p>The event mechanism is a key feature of Starling's architecture. Objects can communicate 
     *  with each other through events. Compared the the Flash event system, Starling's event system
     *  was simplified. The main difference is that Starling events have no "Capture" phase.
     *  They are simply dispatched at the target and may optionally bubble up. They cannot move 
     *  in the opposite direction.</p>
     * 
     *  <p>As in the conventional Flash classes, display objects inherit from EventDispatcher 
     *  and can thus dispatch events. Beware, though, that the Starling event classes are 
     *  <em>not compatible with Flash events:</em> Starling display objects dispatch 
     *  Starling events, which will bubble along Starling display objects - but they cannot 
     *  dispatch Flash events or bubble along Flash display objects.</p>
     *  
     *  @see Event
     *  @see starling.display.DisplayObject DisplayObject
     */
    public class EventDispatcher
    {
        private var mEventListeners:Dictionary;
        
        /** Creates an EventDispatcher. */
        public function EventDispatcher()
        {  }
        
        /** Registers an event listener at a certain object. The 'useWeakReference' parameter
         *  determines whether the reference to the listener is strong or weak. 
         *  A strong reference (the default) prevents your listener from being garbage-collected; 
         *  a weak reference does not. */
        public function addEventListener(type:String, listener:Function, useWeakReference:Boolean=false):void
        {
            if (mEventListeners == null)
                mEventListeners = new Dictionary();
            
            var listeners:Vector.<Reference> = mEventListeners[type];
            var reference:Reference = new Reference(listener, useWeakReference);
            
            if (listeners == null)
                mEventListeners[type] = new <Reference>[reference];
            else
            {
                // check for duplicates
                for each (var ref:Reference in listeners)
                    if (ref.target == listener) return;
                
                mEventListeners[type] = listeners.concat(new <Reference>[reference]);
            }
        }
        
        /** Removes an event listener from the object. */
        public function removeEventListener(type:String, listener:Function):void
        {
            if (mEventListeners)
            {
                var listeners:Vector.<Reference> = mEventListeners[type];
                if (listeners)
                {
                    listeners = listeners.filter(
                        function(item:Reference, ...rest):Boolean { return item.target != listener; });
                    
                    if (listeners.length == 0)
                        delete mEventListeners[type];
                    else
                        mEventListeners[type] = listeners;
                }
            }
        }
        
        /** Removes all event listeners with a certain type, or all of them if type is null. 
         *  Be careful when removing all event listeners: you never know who else was listening. */
        public function removeEventListeners(type:String=null):void
        {
            if (type && mEventListeners)
                delete mEventListeners[type];
            else
                mEventListeners = null;
        }
        
        /** Dispatches an event to all objects that have registered for events of the same type. */
        public function dispatchEvent(event:Event):void
        {
            var listeners:Vector.<Reference> = mEventListeners ? mEventListeners[event.type] : null;
            if (listeners == null && !event.bubbles) return; // no need to do anything
            
            // if the event already has a current target, it was re-dispatched by user -> we change 
            // the target to 'this' for now, but undo that later on (instead of creating a clone)

            var previousTarget:EventDispatcher = event.target;
            if (previousTarget == null || event.currentTarget != null) event.setTarget(this);
            
            var stopImmediatePropagation:Boolean = false;
            var numListeners:int = listeners == null ? 0 : listeners.length;
            
            if (numListeners != 0)
            {
                event.setCurrentTarget(this);
                
                // we can enumerate directly over the vector, since "add"- and "removeEventListener" 
                // won't change it, but instead always create a new vector.
                
                for (var i:int=0; i<numListeners; ++i)
                {
                    var listener:Function = listeners[i].target as Function;
                    var numArgs:int = listener.length;
                    
                    if (numArgs == 0) listener();
                    else if (numArgs == 1) listener(event);
                    else listener(event, event.data);
                    
                    if (event.stopsImmediatePropagation)
                    {
                        stopImmediatePropagation = true;
                        break;
                    }
                }
            }
            
            if (!stopImmediatePropagation && event.bubbles && !event.stopsPropagation && 
                this is DisplayObject)
            {
                var targetDisplayObject:DisplayObject = this as DisplayObject;
                if (targetDisplayObject.parent != null)
                {
                    event.setCurrentTarget(null); // to find out later if the event was redispatched
                    targetDisplayObject.parent.dispatchEvent(event);
                }
            }
            
            if (previousTarget) 
                event.setTarget(previousTarget);
        }
        
        /** Dispatches an event with the given parameters to all objects that have registered for 
         *  events of the given type. The method uses an internal pool of event objects to avoid 
         *  allocations. */
        public function dispatchEventWith(type:String, bubbles:Boolean=false, data:Object=null):void
        {
            if (bubbles || hasEventListener(type)) 
            {
                var event:Event = Event.fromPool(type, bubbles, data);
                dispatchEvent(event);
                Event.toPool(event);
            }
        }
        
        /** Returns if there are listeners registered for a certain event type. */
        public function hasEventListener(type:String):Boolean
        {
            return mEventListeners != null && type in mEventListeners;
        }
    }
}