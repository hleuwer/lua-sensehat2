#!/usr/bin/env lua

--
-- Derived from python version found in https://github.com/ct7aez/sensehatbinclock
-- H. Leuwer
--
local sense = require "sensehat"
local posix = require "posix"

local coltab = {
   year = {0, 127, 0},
   month = {0, 0, 127},
   day = {127, 0, 0},
   hour = {0, 127, 0},
   min = {0, 0, 127},
   sec = {127, 0, 0},
   hundrefths = {60, 60, 60},
   weekday  = {120, 120, 0},
   dst = {100, 100, 0},
   off = {0, 0, 0},
   on = {127, 127, 127}
}

local state = "unknown"

local onoff = {
   off = {
      hour = 22,
      min = 30
   },
   on = {
      hour = 9,
      min = 0
   }
}

sense.ledOff()

---
-- Convert to binary string: MSB ... LSB
--
local function toBin(x)
   local ret = ""
   while x ~= 1 and x ~= 0 do
      ret = tostring(x % 2) .. ret
      x = math.modf(x / 2)
   end
   -- make sure to have 8 digits
   ret = string.rep("0", 7-#ret) .. tostring(x) .. ret
   return ret
end

---
-- Display binary string: Bit 0 most right
--
local function displayBinary(value, row, color)
   binary_str = toBin(value)
   local lb = #binary_str
   for x = 1, 8 do
      if string.sub(binary_str, x, x) == "1" then
         sense.setPixel(7 - lb + x, row, color)
      else
         sense.setPixel(7 - lb + x, row, coltab.off)
      end
   end
end

---
-- Display dayligh saving
--
local function displayDst()
   if os.date("*t").isdst == true then
      coltab.weekday = {127, 127, 0}
   else
      coltab.weekday = {0, 127, 127}
   end
end

---
-- Check on/off state
--
local function checkOnOff(now)
   if state == "on" then
      if now.hour == onoff.off.hour and now.min == onoff.off.min then
         sense.showMessage("GuteNacht", 0.1, sense.colors.red)
	 sense.ledOff()
         state = "off"
      end
   elseif state == "off" then
      if now.hour == onoff.on.hour and  now.min == onoff.on.min then
         sense.showMessage("Moin Moin", 0.2, sense.colors.blue)
         state = "on"
      end
   elseif state == "unknown" then
      on_mins = onoff.on.hour * 60 + onoff.on.min
      off_mins = onoff.off.hour * 60 + onoff.off.min
      now_mins = now.hour * 60 + now.min
      if now_mins >= on_mins and now_mins < off_mins then
         sense.showMessage("ON", 0.2, sense.colors.blue)
         state = "on"
      else
         sense.showMessage("OFF", 0.2, sense.colors.red)
         state = "off"
      end
   end
   return state
end

local function main(...)
   local osec
   while true do
      local t = os.date("*t")
      local w = posix.gettimeofday()
      if checkOnOff(t) == "on" then
         displayBinary(t.year % 100, 0, coltab.year)
         displayBinary(t.month, 1, coltab.month)
         displayBinary(t.day, 2, coltab.day)
         displayDst()
         displayBinary(t.wday, 3, coltab.weekday)
         displayBinary(t.hour, 4, coltab.hour)
         displayBinary(t.min, 5, coltab.min)
         displayBinary(t.sec, 6, coltab.sec)
         displayBinary(math.modf(w.usec / 10000), 7, coltab.hundrefths)
      end
      sense.sleep(0.0001)
   end
end

main()
