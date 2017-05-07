Yamaha SFG 05/01-S Cartridge Board v1.0
Copyright (c) 2017 RBSC

The Setup
---------

After assembling, the cartridge needs to be programmed in order to function properly. The following steps are necessary:

 1. Upload the Altera's firmware
 2. Program the BIOS with the provided ROM file


How to upload the firmware
--------------------------

The below instructions are for programming the Altera chip.

 1. Solder jumper pins both sides of C3 capacitor (see the picture)
 2. Prepare the ByteBlaster 2 programmer, open the Quartus II software, keep default JTAG selection
 3. Supply 5v power to the cartridge board via jumper pins (mind the correct polarity!)
 4. Connect the ByteBlaster's cable to the AS socket of the cartridge (make sure you connect the cable correctly!)
 5. Click "Autodetect" in Quartus II software, the Altera chip should be found and ready for programming
 6. Use "Change file" option and select the .POF file from the "Firmware" directory
 7. Enable the checkboxes: "Program/Configure", "Verify" and "Blank Check"
 8. Click "Start" and monitor the programming and verification process

If the programming completed successfully, disconnect the ByteBlaster's cable and 5v power from the board.

You must also write the provided ROM file from BIOS directory into the W27C512 EEPROM chip (PLCC32) using any EEPROM programmer.
The ROM file contains 2 different BIOS versions that can be selected by the special jumper on the board.


Using the extension board
-------------------------

The separate extension board was created for the SFG cartridge in order to make available standard SFG sockets - left and right
RCA audio sockets, music keyboard socked and MIDI IN and MIDI OUT sockets. The board can be either mounted on top of the
cartridge or it can be connected to the cartridge with the standard IDE ribbon cable.

IMPORTANT! When connecting the ribbon cable or plugging the extension board on top of the cartridge please make sure that you are
connecting correctly, otherwise damage may occur to your SFG cartridge!


Starting SFG BIOS
-----------------

To start the built-in SFG BIOS make sure that Basic is loaded and type "_musica" or "call musica" without quotes and press Enter.
The BIOS should start immediately. Depending on whether the jumper is installed or not, either the SFG-01 BIOS or SFG-05 BIOS will
be launched. To exit from BIOS software just reboot your MSX.


Notes
-----

If you are using 74HCT04 chip instead of 74LS04 please make sure you add one additional 47pf capacitor. See the 74HCT04_fix_cart.jpg
image for capacitor mounting instructions.


IMPORTANT!
----------

The RBSC provides all the files and information for free, without any liability (see the disclaimer.txt file). The provided information,
software or hardware must not be used for commercial purposes unless permitted by the RBSC. Producing a small amount of bare boards for
personal projects and selling the rest of the batch is allowed without the permission of RBSC.

When the sources of the tools are used to create alternative projects, please always mention the original source and the copyright!


Contact information
-------------------

The members of RBSC group Wierzbowsky, Ptero and DJS3000 can be contacted via the MSX.ORG or ZX-PK.RU forums. Just send a personal
message and state your business.

The RBSC repository can be found here:

https://github.com/rbsc


-= ! MSX FOREVER ! =-
