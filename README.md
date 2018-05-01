# lua-senshat
Use the Raspberry Pi [Sense HAT](https://www.raspberrypi.org/products/sense-hat/) board with Lua.

I very much like Raspberry Pi and it's peripherals. And I very much like Lua as programming language. This is a small experimental project to make the lovely sense hat baord with it's various sensors and it's LED matrix available to Lua programs. 

However, I didn't want to reprogram all the Sense HAT stuff already available in Python. Hence, I have decided to use [lunatic-python](https://labix.org/lunatic-python) as a bridge between Pyhton and Lua. This nice piece of code is freely available at [Github](https://github.com/bastibe/lunatic-python).

Using a bridge between Python interpreter and Lua interpreter in one single process is more efficient than calling the Python interpreter as an external program from Lua for every time when accessing one of the sensors. However, I minimized Python programming and performed type conversion between Python and Lua, especially list to table (and vice versa) conversion by first serializing the object to a text representation and parsing this intermediate format by the other language. I used the penlight pretty print features to serialize Lua tables. The [penlight](https://luarocks.org/modules/steved/penlight) lua library can be freely installed from [Luarocks](https://luarocks.org/modules/steved/penlight).

The module covers all functions of the official [Python API for Sense HAT](https://pythonhosted.org/sense-hat/). However, I renamed most of the functions to use Camel Case format for my own Lua programming convenience.

You do not need to know how to programm in Python in order to use lua-sensehat. 

Notes:

* Functions delivering a python directory under Python deliver a Lua userdata in Lua with the same keys as the directory does in Python. It's easy to convert Python directories to Lua table.
* Python lists are converted into Lua tables.
* Functions that take a list as argument in Python take a Lua table as argument in Lua. 
* Numers and strings are passed as numbers and strings between the two worlds.

Example:

Reading environmental sensors and showing their values and units.

```
sense = require "sensehat"

local sense = require "sensehat"
local fmt = string.format

local stemp = 0
local N = tonumber(arg[1]) or 1000

print("=== SENSORS ===")
print(fmt("relative humidity: %.2f %%", sense.humidity()))
print(fmt("pressure         : %.2f mbar", sense.pressure()))
print(fmt("temperature      : %.2f °C", sense.temperature()))
print(fmt("  from mhumidity : %.2f °C", sense.temperatureFromHumidity()))
print(fmt("  from pressure  : %.2f °C", sense.temperatureFromPressure()))
t1 = os.time()
for i = 1, N do
	local temp = sense.temperature()
	stemp = stemp + temp
end
local t2 = os.time()
local dt = (t2 - t1)*1000/N
print(fmt("average temp.    : %.2f °C", stemp/N))
print(fmt("samples: %d time: %d sec speed: %.3f msec", N, t2 - t1, dt))

