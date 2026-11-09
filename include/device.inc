; Kernel's core device drivers
DEVICE_TERMINAL         = 0
DEVICE_I2C              = 1
DEVICE_KEYBOARD         = 2
DEVICE_MOUSE            = 3
DEVICE_SNES             = 4
DEVICE_SDCARD           = 5

; Device driver functions
DRIVER_ON_REGISTER      = 0
DRIVER_ON_UNREGISTER    = 2
DRIVER_OPEN             = 4
DRIVER_READ_BYTE        = 6
DRIVER_READ_BLOCK       = 8
DRIVER_WRITE_BYTE       = 10
DRIVER_WRITE_BLOCK      = 12
DRIVER_SEEK             = 14
DRIVER_POSITION         = 16
DRIVER_CLOSE            = 18
DRIVER_IOCTL            = 20
DRIVER_ON_IRQ           = 22
DRIVER_STRING           = 24

; Device table size
DRIVER_COUNT = 16

; Device table flags
DEVICE_READING      = (%00000001)
DEVICE_WRITING      = (%00000010)
DEVICE_APPENDING    = (%00000100)
DEVICE_SEEKING      = (%00001000)
DEVICE_BLOCKDEV     = (%00010000)
DEVICE_NO_BANK      = (%00100000)
DEVICE_ROM_BANK     = (%01000000)
DEVICE_RAM_BANK     = (%01100000)
