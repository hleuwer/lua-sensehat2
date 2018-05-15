# Lua Sense Hat 2
Use the Raspberry Pi [Sense HAT](https://www.raspberrypi.org/products/sense-hat/) board with Lua - and only Lua.

[lua-sensehat2](https://github.com/hleuwer/lua-sensehat2) is an improvement of [lua-sensehat](https://github.com/hleuwer/lua-sensehat) which bases on [Python API for Sense HAT](https://pythonhosted.org/sense-hat/) and uses [lunatic-python](https://labix.org/lunatic-python) as a bridge between Lua and Python. The disadvantage of this bridge is complexity, high memory consumption and restricted performance.

Lua Sense Hat 2 does not use the python API any longer, but provides a direct binding to C++ library [RTIMULib2] (https://github.com/richardstechnotes/RTIMULib2) for sensors and a Lua based access to LED matrix and Joystick.
 
Almost all functionality of the official [Python API for Sense HAT](https://pythonhosted.org/sense-hat/) are covered. However, I renamed most of the functions to use Camel Case format for my own Lua programming convenience.

The joystick functionality is now implemented within sensehat.lua and there is no dedicated stick module. Asynchronous event capture is now supporting Lua coroutines rather than thread. See function ```registerTask()```.

I use [SWIG] (http://www.swig.org/) to create he binding for RTIMULib2. As this produces a relatively large shared library a manual binding may be benefitial - but also much more work.

Example:

Reading environmental sensors and showing their values and units.

```
sense = require "sensehat"

local sense = require "sensehat"
local fmt = string.format

local stemp = 0
local N = tonumber(arg[1]) or 1000

print("=== SENSORS ===")
print(fmt("relative humidity: %.2f %%", sense.getHumidity()))
print(fmt("pressure         : %.2f mbar", sense.getPressure()))
print(fmt("temperature      : %.2f °C", sense.getTemperature()))
print(fmt("  from mhumidity : %.2f °C", sense.getTemperatureFromHumidity()))
print(fmt("  from pressure  : %.2f °C", sense.getTemperatureFromPressure()))
t1 = os.time()
for i = 1, N do
	local temp = sense.getTemperature()
	stemp = stemp + temp
end
local t2 = os.time()
local dt = (t2 - t1)*1000/N
print(fmt("average temp.    : %.2f °C", stemp/N))
print(fmt("samples: %d time: %d sec speed: %.3f msec", N, t2 - t1, dt))

