# SM_Crash_Dump
 A simple crash handler for Super Metroid (SNES)

This resource hijacks Super Metroid's "jump-to-self" crash routine, as well as the BRK instruction vectors, in order to capture register/stack data and display it on-screen. When a BRK is detected, the status register and address where the BRK was encountered are displayed above the stack dump. If configured, multiple pages of information can be displayed. Palettes can be cycled in case the background is transparent and readability is low.

By default, approximately 600h bytes are used in bank $80, but nearly all of it can be moved to any bank up to $BF. Text data and graphics can live anywhere in the rom.


## How to use

### Patch your ROM

1. Download asar from https://github.com/RPGHacker/asar and place it in the \tools\ folder.
2. Rename your unheadered SM rom to `sm.sfc` and place it in the \build\ folder.
3. Run patch_rom.bat to generate a patched rom in \build\ named `sm_debug.sfc`.

### Create an IPS patch

1. Download asar from https://github.com/RPGHacker/asar and place it in the \tools\ folder.
2. Download and install Python 3+ from https://python.org. Windows users will need to set the PATH environmental variable to point to their Python installation folder.
3. Run build_ips.bat to create IPS patch files.
4. Locate the patch files in \build\.


## Customizing the patch

Defines are listed at the top of `CrashHandler.asm`. Set `!EXTRA_PAGES` to 1 if you would like to setup your own debugging pages that the player/tester can navigate through. This can be useful if you suspect a particular address is causing the crash. You may also wish to add instructions for users to submit bug reports for your hack. Check `resources/normal.tbl` to see what characters are available in the font graphics, or edit them as 2bpp uncompressed graphics. The RAM address of the crash dump can be moved just about anywhere, including SRAM. The tilemap buffer won't need to be changed in most cases.


## Thanks

Resources from https://github.com/tewtal/sm_practice_hack were used in this project, such as the graphics, some layer 3 drawing code, and the python script that builds IPS patches.

Thanks to MetConst Discord for advice and feedback. https://discord.com/invite/xDwaaqa

