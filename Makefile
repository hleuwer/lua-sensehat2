MODULE=sensehat.lua
SNMPEXTENSION=senseHat
LEDOFF=ledoff
LUAV=5.2
INSTALL_LUA=/usr/local/share/lua/$(LUAV)
INSTALL_BIN=/usr/local/bin

doc::
	ldoc sensehat.lua

install:
	cp $(MODULE) $(INSTALL_LUA)
	cp $(SNMPEXTENSION) $(INSTALL_BIN)
	cp $(LEDOFF) $(INSTALL_BIN)

uninstall:
	rm -rf $(INSTALL_LUA)/$(MODULE)
	rm -rf $(INSTALL_BIN)/$(SNMPEXTENSION)
	rm -rf $(INSTALL_BIN)/$(LEDOFF)

clean:
	rm -rf `find . -name "*~"`

test-led:
	lua test/led_test.lua

test-imu:
	lua test/imu_test.lua

test-joy:
	lua test/joy_test.lua

test-sensor:
	lua test/sensor_test.lua

test: test-led test-imu test-joy test-sensor
