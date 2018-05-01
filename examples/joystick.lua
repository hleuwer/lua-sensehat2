local sense = require "sensehat"

local pixels = {
   up     = {{3,0},{4,0}},
   down   = {{3,7},{4,7}},
   left   = {{0,3},{0,4}},
   right  = {{7,3},{7,4}},
   middle = {{3,3},{4,3},{3,4},{4,4}},
}

local function setPixels(pixels, col)
   for i,p in ipairs(pixels) do
      sense.setPixel(p[1]+1,p[2]+1,col)
   end
end

function handleEvent(event, color)
   setPixels(pixels[event.direction], color)
end

black, white  = {0,0,0}, {255,255,255}

local running = true

while running == true do
   local event = sense.stick.waitEvent()
   if event.action == "pressed" then
      handleEvent(event, white)
   elseif event.action == "released" then
      handleEvent(event, black)
   end
end
