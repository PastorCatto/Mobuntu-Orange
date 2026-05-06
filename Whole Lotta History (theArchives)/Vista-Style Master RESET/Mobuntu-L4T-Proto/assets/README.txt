Drop hekate-compatible BMP files here:

  icon.bmp       -- 256x256 24-bit BMP (boot menu icon)
  bootlogo.bmp   -- 720p 24-bit BMP   (boot splash)

Hekate is picky: must be 24-bit Windows BMP, no alpha channel.
GIMP -> Export As -> BMP -> Advanced Options -> 24 bits / R8 G8 B8.

Until you drop real files here, stage 05 will warn and skip them.
The hekate ini will still reference the paths; the boot menu just shows
default placeholder graphics.
