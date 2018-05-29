local sense = require "sensehat"
local socket = require "socket"

local function printf(fmt, ...)
   print(string.format(fmt, ...)) 
end

print("=== JOYSTICK ===")
local cbcount = 0
local function cb(ev, param)
   print(ev, param, cbcount)
   cbcount = cbcount + 1
end

local function tsk1(ev, param)
   local n = 100
   while true do
      local ev = sense.receiveEvent()
      print(ev, param, n)
      if ev.action ~= "held" then
         n = n + 1
      end
   end
end

local function tsk2(ev, param)
   local n = 1000
   while true do
      local ev = sense.receiveEvent()
      print(ev, param, n)
      if ev.action ~= "held" then
         n = n + 1
      end
   end
end

print("Waiting for event ...")
local ev = sense.waitEvent(false)
print("   event received: ", ev)

sense.registerCallback("up", cb, "stick up")
sense.registerCallback("down", cb, "stick down")
sense.registerTask("left", tsk1, "stick left")
sense.registerTask("right", tsk2, "stick right")
sense.registerCallback("enter", cb, "stick middle")
--sense.registerCallback("middle", function(ev) print("exiting ...") os.exit(1) end)
sense.loop()
