local E={} -- EventEmitter
E.__index=E
local tunpack,trun=table.unpack,ba.thread.run

function E:on(event,cb)
   local ev=self._evs[event]
   if not ev then ev={} self._evs[event]=ev end
   ev[cb]=true
   local payload = self._retained and self._retained[event]
   if payload then trun(function() cb(event,tunpack(payload)) end) end
   return true
end

function E:emit(event,...)
   local evName
   if "table" == type(event) then
      evName=event.name
      if evName and event.retain then
	 self._retained=self._retained or {}
	 self._retained[evName] = {...}
      end
   else
      evName=event
   end
   if "string" ~= type(evName) then error("Invalid event",2) end
   local ev=self._evs[evName]
   if ev then
      for cb in pairs(ev) do
	 local ok,err = pcall(cb,evName,...)
	 if not ok then
	    if self.reporterr then
	       self.reporterr(evName,cb,err)
	    else
	       trace("Event CB err:",evName,cb,err)
	    end
	 end
      end
      return true
   end
   return false
end

function E:removeListener(event,cb2rem)
   local ret=false
   local evs=self._evs
   local ev=evs[event]
   if ev then
      if cb2rem then
	 ret=ev[cb2rem] and true or false
	 ev[cb2rem]=nil
	 if not next(ev) then evs[event]=nil end
      else
	 evs[event]=nil
	 ret=true
      end
   end
   return ret
end

return {
   create=function(self) -- Constructor
	     local self=setmetatable(self or {},E)
	     self._evs={}
	     return self
	  end
}
