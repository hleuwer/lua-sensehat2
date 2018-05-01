-------------------------------------------------------------------------------
-- Raspberry Pi Sensehat programming in Lua.
-- Main module: humidity, pressure, temperature sensors and inertial sensor IMU
-- @module sensehat.lua
-- @copyright (c) Herbert Leuwer, April 2018
-- @license MIT
-------------------------------------------------------------------------------

local mat = require "matrix"
local lfs = require "lfs"
local pretty = require "pl.pretty"
local socket = require "socket"
local posix = require "posix"
local pwd = require "posix.pwd"
local alien = require "alien"
local rtimu = require "rtimu"

local libc = alien.default

--
-- Make requently used functions local.
--
local band, rshift, lshift = bit32.band, bit32.rshift, bit32.lshift
local tinsert, tconcat = table.insert, table.concat
local format = string.format
local ioctl = libc.ioctl

--
-- Constants.
--
local SENSE_HAT_FB_NAME = 'RPi-Sense FB'
local SENSE_HAT_FB_FBIOGET_GAMMA = 61696   -- ioctl request to get gamma
local SENSE_HAT_FB_FBIOSET_GAMMA = 61697   -- ioctl request to set gamma
local SENSE_HAT_FB_FBIORESET_GAMMA = 61698 -- ioctl request to reset gamma
local SENSE_HAT_FB_GAMMA_DEFAULT = 0       -- 
local SENSE_HAT_FB_GAMMA_LOW = 1
local SENSE_HAT_FB_GAMMA_USER = 2
local SETTINGS_HOME_PATH = '.config/sense_hat'
local TEXT_IMAGE_FILE = "/usr/local/share/sense_hat/sense_hat_text.png"
local TEXT_FILE = "/usr/local/share/sense_hat/sense_hat_text.txt"

local imuSettingsFile = "RTIMULib"

--
-- Output helpers.
--
local function printf(fmt, ...)
   print(format(fmt, ...))
end

local function dprintf(fmt, ...)
   printf("==> "..fmt, ...)
end

--
-- Pretty print pixel.
--
local function ppt(t)
   return pretty.write(t, "", false)
end

--
-- Metatable for pixelmap.
--
local function setmeta(pixels)
   setmetatable(pixels, {
                   __tostring = pix2str
   })
   return pixels
end

--
-- Table helpers.
--
local function trange(t, from, to)
   to = to or #t
   local u = {}
   if from < 0 then
      from = from + #tab
   end
   if to < 0 then
      to = to + #tab
   end
   for i = from, to do
      tinsert(u, t[i])
   end
   setmeta(u)
   return u
end

local function tappend(t1, t2)
   for i, v in ipairs(t2) do
      tinsert(t1, v)
   end
   setmeta(t1)
   return t1
end

local function treverse(t)
   local n = #t
   local u = {}
   local p
   for i = 1, n do
      p = t[i]
      u[n-i+1] = t[i]
   end
   setmeta(t)
   return u
end


local function tequal(t1, t2)
   if #t1 == 0 then return false end
   for i,v in ipairs(t1) do
      if t2[i] ~= v then
         return false
      end
   end
   return true
end

local function tdel(t, from, to)
   to = to or #t
   if from < 0 then
      from = #t + from
   end
   if to < 0 then
      to = #t + to
   end
   for i = from, to do
      tremove(t, from)
   end
   setmeta(t)
   return t
end

local function tfill(t, elem, n)
   for i = 1, n do
      tinsert(t, elem)
   end
   setmeta(t)
   return t
end

local function tcopy(inp)
   local t = {}
   for k,v in pairs(inp) do
      t[k] = v
   end
   setmetatable(t,
                {
                   __tostring = function(raw)
                      return format("{x = %f, y = %f, z = %f}", raw.x, raw.y, raw.z)
                   end
   })
   return t
end

--
-- Convert pixels into string for terminal output.
-- Note: Differentiates only white against others.
--
local function pix2str(pixels)
   local s = ""
   local t = {}
   for i,v in ipairs(pixels) do
      if v[1] < 1 and v[2] < 1 and v[3] < 1 then
         s = s .. " ."
      else
         if v[1] == 255 then
            s = s .. " R"
         elseif v[2] == 255 then
            s = s .. " G"
         elseif v[3] == 255 then
            s = s .. " B"
         else
            s = s .. " ?"
         end
      end
      if i > 1 and (i) % 8 == 0 then
         tinsert(t, s)
         s = ""
      end
   end
   return tconcat(t, "\n")
end

--
-- Reads (copy first) settings file RTIMULib.ini
-- 
local function getSettingsFile(filename)
   local inifile = string.format("%s.ini", filename)
   local homedir = pwd.getpwuid(io.popen("id -u"):read()).pw_dir
   local homepath = homedir .. "/" .. SETTINGS_HOME_PATH
   if not lfs.attributes(homepath) then
      lfs.mkdir(homepath)
   end
   local homefile = homepath .. "/" .. inifile
   local homeexists = lfs.attributes(homefile) ~= nil
   local systemfile = "/etc/" .. inifile
   local systemexists = lfs.attributes(systemfile) ~= nil
   if systemexists and not homeexists then
      io.popen("cp " .. systemfile .. " " .. homefile):read()
   end
   return rtimu.RTIMUSettings(homepath .. "/" .. filename)
   
end

--
-- Init IMU
--
local settings = getSettingsFile(imuSettingsFile)
local imu = rtimu.RTIMU_createIMU(settings)
local data = rtimu.RTIMU_DATA()
local humidity = rtimu.RTHumidity_createHumidity(settings)
local pressure = rtimu.RTPressure_createPressure(settings)

--
-- Load an image from file into a pixel list.
-- Note: We use image magick convert utility to read the
--       the pixels of the image directly into a Lua string via
--       pipe.
--
local function loadImageFile(file)
   local s = io.popen("convert " .. file .." rgb:-"):read("*a")
   local t = {}
   for i = 1, #s, 3 do
      local r, g, b = s:byte(i, i+2)
      tinsert(t, {r, g, b})
   end
   setmeta(t)
   return t
end


--
-- Creates assets for text display from image file and text file.
-- Text patterns are stored in an image
--
local function loadTextAssets(imagefile, textfile)
   local textpixels = loadImageFile(imagefile, false)
   local f = assert(io.open(textfile, "r"))
   local text = f:read("*a")
   local pixeltext = {}
   for i = 1, #text do
      local tstart = (i-1) * 40   
      local tend = tstart + 39
      local char = trange(textpixels, tstart + 1, tend + 1)
      pixeltext[text:sub(i, i)] = char
      setmeta(char)
   end
   return pixeltext
end

--
-- Convert pixel map (for rotation) into a printable string.
--
local function map2str(map)
   local t = {}
   for i,v in ipairs(map) do
      local s = ""
      for j, w in ipairs(v) do
         s = s .. format(" %2d", w)
      end
      tinsert(t, s)
   end
   return tconcat(t, "\n")
end

--
-- Create pixel maps for each possible rotation: 0, 90, 180, 270.
-- pix map is used for rotation.
--
local pixMap0 = {
   {0,   1,  2,  3,  4,  5,  6,  7},
   {8,   9, 10, 11, 12, 13, 14, 15},
   {16, 17, 18, 19, 20, 21, 22, 23},
   {24, 25, 26, 27, 28, 29, 30, 31},
   {32, 33, 34, 35, 36, 37, 38, 39},
   {40, 41, 42, 43, 44, 45, 46, 47},
   {48, 49, 50, 51, 52, 53, 54, 55},
   {56, 57, 58, 59, 60, 61, 62, 63}
}
setmetatable(pixMap0, {__tostring = map2str})
local pixMap90 = mat.rotl(pixMap0)
setmetatable(pixMap90, {__tostring = map2str})
local pixMap180 = mat.rotl(pixMap90)
setmetatable(pixMap180, {__tostring = map2str})
local pixMap270 = mat.rotl(pixMap180)
setmetatable(pixMap270, {__tostring = map2str})

local pixMap = {
   [0] = pixMap0,
   [90] = pixMap90,
   [180] = pixMap180,
   [270] = pixMap270
}

local rotation = 0
local letterMap = loadTextAssets(TEXT_IMAGE_FILE, TEXT_FILE)
local fbDevice = nil


--
-- Read pixels for given character.
--
local function getCharPixels(s)
   if #s == 1 and letterMap[s] then
      return letterMap[s]
   else
      return letterMap["?"]
   end
end

--
-- Trims white space pixels from front and back of a loaded
-- text character.
--
local function trimSpace(char)
   local psum = function(x)
      local sum = 0
      for k,v in ipairs(x) do
         if tequal(x, colors.black) == true then
            sum = sum + 1
         end
      end
      return sum
   end
   if psum(char) > 0 then
      local is_empty = true
      while is_empty do
         local row = trange(char, 1, 8)
         if psum(row) ~= 0 then
            is_empty = false
         end
         if is_empty == true then
            tdel(char, 1, 8)
         end
      end
      is_empty = true
      while is_empty do
         local row = trange(char, -8)
         if psum(row) ~= 0 then
            is_empty = false
         end
         if is_empty == true then
            tdel(char, -8)
         end
      end
   end
   return char
end

--
-- Get name of frame buffer device.
--
local function getFbDevice()
   for fn in lfs.dir("/sys/class/graphics") do
      if string.sub(fn, 1, 2) == "fb" then
         local name = io.open("/sys/class/graphics/"..fn.."/name", "r"):read("*l")
         if name == SENSE_HAT_FB_NAME then
            local fbdev = "/dev/"..fn
            if io.open(fbdev,"r") then
               return fbdev
            end
         end
      end
   end
end

--
-- Init humidity.
--
local humidityIniFlag = false
local function initHumidity()
   if humidityIniFlag == false then
      humidityIniFlag = assert(humidity:humidityInit() == true, "Cannot init humidity sensor.")
   end
end

--
-- Init pressure.
--
local pressureIniFlag = false
local function initPressure()
   if pressureIniFlag == false then
      pressureIniFlag = assert(pressure:pressureInit() == true, "Cannot init pressure sensor.")
   end
end

--
-- Initialize IMU.
--
local imuInitFlag = false
local imuPollInterval = 0
local compassEnabled = false
local gyroEnabled = false
local accelEnabled = false
local lastOrientation = {pitch = 0, roll = 0, yaw = 0}
local raw = {x = 0, y = 0, z = 0}
local lastAccelRaw = tcopy(raw)
local lastCompassRaw = tcopy(raw)
local lastGyroRaw = tcopy(raw)

local function _configImu(compassEna, gyroEna, accelEna)
   assert(type(compassEna) == "boolean" and type(gyroEna) == "boolean" and type(accelEna) == "boolean",
          "All parameters for setImuConfig must be of type 'boolean'")
   if compassEnabled ~= compassEna then
      compassEnabled = compassEna
      imu:setCompassEnable(compassEnabled)
   end
   if gyroEnabled ~= gyroEna then
      gyroEnabled = gyroEna
      imu:setGyroEnable(gyroEnabled)
   end
   if accelEnabled ~= accelEna then
      accelEnabled = accelEna
      imu:setAccelEnable(accelEnabled)
   end
   return true
end

local function _initImu()
   if imuInitFlag == false then
      imuInitFlag = assert(imu:IMUInit() == true, "Cannot init IMU")
      imuPollInterval = imu:IMUGetPollInterval() * 0.001
      return _configImu(true, true, true)
   end
   return true
end

local function initImu()
   return _initImu()
end

local function readImu()
   initImu()
   local attempts = 0
   local success = false
   local data
   while success == false and attempts < 3 do
      success  = imu:IMURead()
      attempts = attempts + 1
      sleep(imuPollInterval)
   end
   return success
end

local function getRawData(validkey, datakey)
   local chk = readImu()
   if chk == true then
      local data = imu:getIMUData()
      if data[validkey] == true then
         local raw = data[datakey]
         return {
            x = raw:x(),
            y = raw:y(),
            z = raw:z()
         }
      end
   end
end

-------------------------------------------------------------------------------
-- Sense Hat Module
-------------------------------------------------------------------------------
local M = {}
_ENV = setmetatable(M,{
      __index = _G
})


-------------------------------------------------------------------------------
-- LED matrix control.
-- @section LED.
-------------------------------------------------------------------------------

local red = {255, 0, 0}
local green = {0, 255, 0}
local blue = {0, 0, 255}
local yellow = {255, 255, 0}
local violett = {255, 0, 255}
local white = {255, 255, 255}
local black = {0, 0, 0}      

---
-- Predefined pixel colors.
---
colors = {
   red = red,
   green = green,
   blue = blue,
   yellow = yellow,
   violett = violett,
   white = white,
   black = black
}

red = colors.red
green = colors.green
blue = colors.blue
black = colors.black
white = colors.white
local D = colors.black
local W = colors.white

local off = {
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
   D, D, D, D, D, D, D, D,
}
local on = {
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W,
   W, W, W, W, W, W, W, W
}
local checkerboard = { 
   W, W, D, D, W, W, D, D,
   W, W, D, D, W, W, D, D,
   D, D, W, W, D, D, W, W,
   D, D, W, W, D, D, W, W,
   W, W, D, D, W, W, D, D,
   W, W, D, D, W, W, D, D,
   D, D, W, W, D, D, W, W,
   D, D, W, W, D, D, W, W,
}

---
-- LED matrix Patterns.
---
pattern = {
   off = off, -- display off
   on = on, -- display on
   checkerboard = checkerboard -- checkerboard
}

---
-- Get the letter map for a letter.
-- @param s string to look up.
-- @return pixel field representing the letter.
---
function getLetterMap(s)
   if s == nil then
      return letterMap
   else
      return letterMap[s]
   end
end

---
-- Convert pixel into 16 bit rgb565 value.
-- Format: (hi,lo) = (rrrrrggg, gggbbbbb).
-- @param pix Pixel {r,g,b} to convert.
-- @return Two byte value representing pixel in rgb565 notation.
---
function packPixel(pix)
   local r = band(rshift(pix[1], 3), 0x1f)
   local gh = band(rshift(pix[2], 5), 0x7)
   local gl = band(pix[2], 0x7)
   local g = band(rshift(pix[2], 2), 0x3f)
   local b = band(rshift(pix[3], 3), 0x1f)
   local s = string.char(lshift(gl,5) + b) .. string.char(lshift(r, 3) + gh)
   return s 
end

---
-- Convert rgb565 value into pixel.
-- @param rgb Number representing pixel to convert.
-- @return Table {r,g,b} describing the pixel.
---
function unpackPixel(rgb)
   local lo,hi = rgb:byte(1,2)
   local r = band(hi, 0xf8)
   local g = band(lshift(hi, 5), 0xe0) + band(rshift(lo, 5), 7)
   local b = band(lshift(lo, 3), 0xf8)
   return {r, g, b}
end


---
-- Get current rotation of diaplay.
-- @return Rotation as number 0, 90, 180 or 270.
---
function getRotation()
   return rotation
end

---
-- Set a single pixel.
-- @param x Number representing x coordinate.
-- @param y Number reprenseting y coordinate.
-- @param ... PIxel as table or numbers.
-- @usage setPixel(1, 2, r, g, b)
-- @usage setPixel(1, 2, {r, g, b})
---
function setPixel(x, y, ...)
   arg = {select(1, ...)}
   local pixel
   if #arg == 1 then
      pixel = arg[1]
   elseif #arg == 3 then
      pixel = arg
   else
      error("Pixel argument must be given as {r, g, b} or r, g, b")
   end
   assert(x >= 0 and x < 8, "X position must be between 0 and 7")
   assert(y >= 0 and y < 8, "Y position must be between 0 and 7")
   for e in ipairs(pixel) do
      assert(e >= 0 and e < 256, "Pixel elements must be between 0 and 255")
   end
   local f = assert(io.open(fbDevice, "wb"))
   local map = pixMap[getRotation()]
   f:seek("set", map[x+1][y+1] * 2)
   f:write(packPixel(pixel))
   f:close()
end

---
-- Get pixel from frame buffer at given position.
-- @param x X coordinate.
-- @param y y coordinate.
-- @return Pixel as table {r,g,b}.
---
function getPixel(x, y)
   assert(x >= 0 and x < 8, "X position must be between 0 and 7")
   assert(y >= 0 and y < 8, "Y position must be between 0 and 7")
   local pix
   local f = assert(io.open(fbDevice, "rb"))
   local map = pixMap[rotation]
   f:seek("set", map[x+1][y+1] * 2)
   return unpackPixel(f:read(2))
end

---
-- Display pixels defined in a list of pixels.
-- The function may display only a subset of possible 64 (8x8) pixels.
-- @param pixels List of pixels {{r,g,b}, ..., {r,g,b}}
---
function setPixels(pixels)
   assert(#pixels == 64, format("Pixel matrix must have 64 elements, received %d", #pixels))
   for i, pix in ipairs(pixels) do
      assert(#pix == 3, format("Pixel tuple at index %d is invalid.", i))
      for j, col in ipairs(pix) do
         assert(col >= 0 and col < 256, format("Pixel %d at index %d is invalid.", j, i))
      end
   end
   local f = assert(io.open(fbDevice, "wb"))
   local map = pixMap[getRotation()]
   for i, pix in ipairs(pixels) do
      assert(#pix == 3, format("Pixel at index %d is invalid - must have 3 elements.", i))
      local r, c = math.floor((i-1)/8), (i-1) % 8
      f:seek("set", map[r+1][c+1] * 2)
      local rgb = packPixel(pix)
      f:write(rgb)
   end
   f:close()
end

---
-- Read pixels from frame buffer.
-- The function always returns all 64 (8x8) pixels.
-- @return List of pixels.
---
function getPixels()
   local pixels = {}
   local f = io.open(fbDevice, "rb")
   local map = pixMap[getRotation()]
   for row = 0,7 do
      for col = 0,7 do
         f:seek("set", map[row+1][col+1] * 2)
         local pix = unpackPixel(f:read(2))
         tinsert(pixels, pix)
      end
   end
   setmeta(pixels)
   f:close()
   return pixels
end

---
-- Set Rotation.
-- @param r Rotation value: 0, 90,180, 270 degree.
-- @param redraw Boolean value. If set the display is redrawn.
--               If not set, only the module's rotation parameter is set.
---
function setRotation(r, redraw)
   r = r or 0
   if redraw == nil then redraw = true end
   assert(r == 0 or r == 90 or r == 180 or r == 270, "Rotation must be 0, 90, 180, 270 degrees")
   local pixels
   if redraw == true then
      pixels = getPixels()
   end
   rotation = r
   if redraw == true then
      setPixels(pixels)
   end
end

---
-- Clear the display.
-- If no color is given 'black' is used as color.
-- @param ... Table with color definition.
-- @usage clear(r,g,b)
-- @usage clear{r,g,b}
---
function clear(...)
   local black = {0, 0, 0}
   local arg = {select(1, ...)}
   local color
   if #arg == 0 then
      color = black
   elseif #arg == 1 then
      color = arg[1]
   elseif #arg == 3 then
      color = arg
   else
      error("Pixel argument must be given as {r, g, b} or r, g, b")
   end
   local t = {}
   for i = 1, 64 do
      t[i] = color
   end
   setmeta(t)
   setPixels(t)
end

---
-- Show a letter.
-- @param s Letter to display (string).
-- @param fg Foreground color as table (default: white).
-- @param bg Background color as table (default: black).
---
function showLetter(s, fg, bg)
   local fg = fg or colors.white
   local bg = bg or colors.black
   assert(#s == 1, "Only one single character/ascii may be passed into this method.")
   local prev_rotation = getRotation() 
   if getRotation() == 0 then 
      setRotation(270, false)
   else
      setRotation(prev_rotation - 90, false)
   end
   local pixels = {}
   for i = 1, 8 do tinsert(pixels, {-1, -1, -1}) end
   local text_pixels = getCharPixels(s)
   tappend(pixels, text_pixels)
   for i = 1, 16 do tinsert(pixels, {-1, -1, -1}) end
   local coloured_pixels = {}
   for i = 1, #pixels do
      local pix = pixels[i]
      if tequal(pix, colors.white) == true then
         tinsert(coloured_pixels, fg)
      else
         tinsert(coloured_pixels, bg)
      end
   end
   setmeta(coloured_pixels)
   setPixels(coloured_pixels)
   setRotation(prev_rotation, false)
end

---
-- Load an image from file into a pixel list and optinally display.
-- Note: We use image magick convert utility to read the
--       the pixels of the image directly into a Lua string via
--       pipe.
-- @param file File to load and optionally display.
-- @param redraw Boolean value. If true, show image on display.
---@return List of pixels.
---
function loadImage(file, redraw)
   if redraw == nil then redraw = true end
   local pixels = loadImageFile(file)
   if redraw == true then
      setPixels(pixels)
   end
   return pixels
end

---
-- Flip display horizontal.
-- @param redraw Redraw if nil or true (default true).
-- @return Flipped Pixels
---
function flipHorizontal(redraw)
   if redraw == nil then redraw = true end
   local pixels = getPixels()
   local flipped = {}
   setmeta(flipped)
   for i = 0, 7 do
      offset = i * 8
      tappend(flipped, treverse(trange(pixels, offset + 1, offset + 8)))
   end
   if redraw == true then
      setPixels(flipped)
   end
   return flipped
end

---
-- Flip display vertical.
-- @param redraw Redraw if nil or true (default true).
-- @return Flipped Pixels
---
function flipVertical(redraw)
   if redraw == nil then redraw = true end
   local pixels = getPixels()
   local flipped = {}
   setmeta(flipped)
   for i = 7, 0, -1 do
      offset = i * 8
      tappend(flipped, trange(pixels, offset + 1, offset + 8))
   end
   if redraw == true then
      setPixels(flipped)
   end
   return flipped
end

flipH = flipHorizontal
flipV = flipVertical

---
-- Display a moving message.
-- @param message Message to display.
-- @param speed Speed in seconds per pixel shift.
-- @param fg Foreground color.
-- @param bg Background color.
---
function showMessage(message, speed, fg, bg)
   if speed == nil then speed = 1 end
   if fg == nil then fg = white end
   if bg == nil then bg = black end
   local prev_rotation = getRotation()
   if prev_rotation == 0 then
      setRotation(270)
   else
      setRotation(prev_rotation - 90)
   end
   local dummycol = {-1, -1, -1}
   local string_padding = tfill({}, dummycol, 64)
   local letter_padding = tfill({}, dummycol, 8)
   local scroll_pixels = {}
   tappend(scroll_pixels, string_padding)
   for i = 1, #message do
      tappend(scroll_pixels, trimSpace(getCharPixels(message:sub(i,i))))
      tappend(scroll_pixels, letter_padding)
   end
   tappend(scroll_pixels, string_padding)
   local coloured_pixels = setmeta({})
   for i = 1, #scroll_pixels do
      local pix = scroll_pixels[i]
      if tequal(pix, colors.white) == true then
         tinsert(coloured_pixels, fg)
      else
         tinsert(coloured_pixels, bg)
      end
   end
   local scroll_length = math.floor(#coloured_pixels / 8)
--   dprintf("coloured pix:\n%s", tostring(coloured_pixels))
   for i = 1, scroll_length - 8 do
      local start = (i-1) * 8 + 1
      local ende = start + 63
      setPixels(trange(coloured_pixels, start, ende))
      sleep(speed)
   end
   setRotation(prev_rotation)
end

---
-- The gamma attributes provides a means to define the least significant
-- 5 bits of a color value. These bits are replaced by the value given
-- in a lookup table using the index as key and the stored value as
-- replacement. The value must be in the range of 0 to 31.
-- @param buf Lookup table with 32 values.
---
function setGamma(buf)
   assert(#buf == 32, "Gamma array must be of length of 32.")
   local buffer = alien.buffer(32)
   for i, v in ipairs(buf) do
      assert(v, "Gamma value must be between 0 and 31.")
      buffer[i] = v
   end
   local fd = assert(posix.open(fbDevice, posix.O_RDONLY), "Can't open framebuffer file.")
   ioctl:types("int", "int", "ulong", "pointer")
   local err = ioctl(fd, SENSE_HAT_FB_FBIOSET_GAMMA, buffer)
   assert(err == 0, format("Error resetting gamma %q %d.", posix.errno()))
end

---
-- Retviews the current active gamma lookup table.
-- @return Current active gamma lookup table.
---
function getGamma()
   local t = {}
   local buffer = alien.buffer(32)
   ioctl:types("int", "int", "ulong", "pointer")
   local fd = posix.open(fbDevice, posix.O_RDONLY)
   local err = ioctl(fd, SENSE_HAT_FB_FBIOGET_GAMMA, buffer)
   assert(err == 0, format("Error resetting gamma %q %d", posix.errno()))
   for i = 1, 32 do
      t[i] = buffer[i]
   end
   return t
end

---
-- Reset gamma lookup table to default.
---
function resetGamma()
   local fd = posix.open(fbDevice, posix.O_RDONLY)
   ioctl:types("int", "int", "ulong", "ulong")
   local err = ioctl(fd, SENSE_HAT_FB_FBIORESET_GAMMA, SENSE_HAT_FB_GAMMA_DEFAULT)
   assert(err == 0, format("Error resetting gamma %s %d", posix.errno()))
end

---
-- Determine whether gamma is adusted to low light.
-- @return true or false.
---
function getLowLight()
   local gamma = getGamma()
   local res = tequal(gamma, {
                         0, 1, 1, 1, 1, 1, 1, 1,
                         1, 1, 1, 1, 1, 2, 2, 2,
                         3, 3, 3, 4, 4, 5, 5, 6,
                         6, 7, 7, 8, 8, 9, 10, 10
   }), gamma
   return res
end

---
-- Set gamma to low light
-- @param value true or false.
---
function setLowLight(value)
   local fd = posix.open(fbDevice, posix.O_RDONLY)
   local cmd 
   if value == true then
      cmd = SENSE_HAT_FB_GAMMA_LOW
   else
      cmd = SENSE_HAT_FB_GAMMA_DEFAULT
   end
   ioctl:types("int", "int", "ulong", "ulong")
   local err = ioctl(fd, SENSE_HAT_FB_FBIORESET_GAMMA, cmd)
   assert(err == 0, format("Error resetting gamma %q %d", posix.errno()))
end

---
-- Turn LED matrix off.
---
function ledOff()
   setPixels(pattern.off)
end

---
-- Turn LED matrix on.
---
function ledOn()
   setPixels(pattern.on)
end


-------------------------------------------------------------------------------
-- Miscellaneous.
-- @section MISCELLANEOUS
-------------------------------------------------------------------------------

---
-- Sleep for a while.
-- @param sec Sleep time in seconds, e.g. 0.2 seconds.
---
function sleep(sec)
   return socket.sleep(sec)
end

-- Initializations
fbDevice = assert(getFbDevice())

-------------------------------------------------------------------------------
-- Humidity Sensor.
-- @section HUMIDITY
-------------------------------------------------------------------------------

---
-- Read humidity sensor.
-- @return Relative humidity in percent.
---
function getHumidity()
   initHumidity()
   assert(humidity:humidityRead(data) == true, "Cannot read from humidity sensor.")
   if data.humidityValid == true then
      return data.humidity
   else
      return 0
   end
end

---
-- Get humidity sensor name.
-- @return Name of humidity sensor.
---
function getHumidityName()
   return humidity:humidityName()
end

-------------------------------------------------------------------------------
-- Temperature Sensors.
-- @section HUMIDITY
-------------------------------------------------------------------------------

---
-- Read temperature from humidity sensor.
-- @return Temperature in degree celsius.
---
function getTemperatureFromHumidity()
   initHumidity()
   assert(humidity:humidityRead(data) == true, "Cannot read from humidity sensor.")
   if data.temperatureValid == true then
      return data.temperature
   else
      return 0
   end
end

---
-- Read temperature from pressure  sensor.
-- @return Temperature in degree celsius.
---
function getTemperatureFromPressure()
   initPressure()
   assert(pressure:pressureRead(data) == true, "Cannot read from humidity sensor.")
   if data.temperatureValid == true then
      return data.temperature
   else
      return 0
   end
end

---
-- Read temperature.
-- The value is read from humidity sensor.
-- @return Temperature in degree celsius.
---
function getTemperature()
   return getTemperatureFromHumidity()
end

-------------------------------------------------------------------------------
-- Pressure Sensor.
-- @section PRESSURE
-------------------------------------------------------------------------------

---
-- Read pressure sensor.
-- @return Relative pressure in mbar.
---
function getPressure()
   initPressure()
   assert(pressure:pressureRead(data) == true, "Cannot read from pressure sensor.")
   if data.pressureValid == true then
      return data.pressure
   else
      return 0
   end
end

---
-- Get pressure sensor name.
-- @return Name of pressure sensor.
---
function getPressureName()
   return pressure:pressureName()
end

-------------------------------------------------------------------------------
-- IMU  Sensor.
-- @section IMU
-------------------------------------------------------------------------------

---
-- Configure IMU sensor or usage of sensor to calculate orientation.
-- @param compassEna Enable compass.
-- @param gyroEna Enable gyrometer.
-- @param accelEna Enable magnetometer.
---
function configImu(compassEna, gyroEna, accelEna)
   _initImu()
   return _configImu(compassEna, gyroEna, accelEna)
end

---
-- Read orientation in radians using all sensors.
-- @return Orientation in radians as table: {roll, pitch, yaw}.
---
function getOrientationRadians()
   local raw = getRawData("fusionPoseValid", "fusionPose")
   if raw ~= nil then
      raw.roll = raw.x
      raw.pitch = raw.y
      raw.yaw = raw.z
      lastOrientation = raw
   end
   return tcopy(raw)
end

---
-- Read orientation in degrees using all sensors..
-- @return Orientation in degrees  as table: {roll, pitch, yaw}.
---
function getOrientationDegrees()
   local orientation = getOrientationRadians()
   for k, v in pairs(orientation) do
      local deg = math.deg(v)
      if deg < 0 then
         orientation[k] = deg + 360
      else
         orientation[k] = deg
      end
   end
   return orientation
end

---
-- Read accelerometer raw data.
-- @return Accelerometer raw data in G or m/s^2 as table {x, y, z}
---
function getAccelerometerRaw()
   local raw = getRawData("accelValid", "accel")
   if raw ~= nil then
      lastAccelRaw = raw
   end
   return tcopy(raw)
end

---
-- Read orientation from accelerometer.
-- @return Orientation from accelerometer in degrees as table {roll, pitch, yaw}.
---
function getAccelerometer()
   configImu(false, false, true)
   return getOrientationDegrees()
end

---
-- Read the gyroscope raw data.
-- @return Gyroscope raw data in rad/s as table {x, y, z}. 
---
function getGyroscopeRaw()
   local raw = getRawData("gyroValid", "gyro")
   if raw ~= nil then
      lastGyroData = raw
   end
   return tcopy(raw)
end

---
-- Read orientation from gyroscope in degrees.
-- @return Orientation from gyroscope in degrees as table {roll, pitch, yaw}.
---
function getGyroscope()
   configImu(false, true, false)
   return getOrientationDegrees()
end

---
-- Read raw compass data in uTesla.
-- @return Compass raw data in uTesla as table {x, y, z}
---
function getCompassRaw()
   local raw = getRawData("compassValid", "compass")
   if raw ~= nil then
      lastCompassRaw = raw
   end
   return tcopy(raw)
end

---
-- Read direction of north from the magnetometer in degrees.
-- @return Direction from north in degrees.
---
function getCompass()
   configImu(true, false, false)
   local orientation = getOrientationDegrees()
   if type(orientation) == "table" and orientation.yaw then
      return orientation.yaw
   else
      return nil
   end
end

return _ENV
