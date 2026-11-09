# Todo List

| Location                      | Description              | Who's working on it?  | Completion % |
|-------------------------------|--------------------------|-----------------------|--------------|
|kernel/sys                     |Kernel base functionality |Stefan                 | 75%          |
|kernel/drivers/ps2kbd.asm      |PS/2 keyboard driver      |                       | 10%          |
|kernel/drivers/terminal.asm    |Terminal/screen driver    |                       | 1%           |
|kernel/font                    |Make a system font        |                       | 5%           |
|shell/                         |Minimal unix like shell   |                       | 1%           |
|kernel/drivers/sdcard.asm      |SD card driver            |                       | 0%           |
|kernel/drivers/snes.asm        |SNES controller driver    |                       | 0%           |
|kernel/drivers/ps2mse.asm      |PS/2 mouse driver         |                       | 0%           |
|kernel/sys/mem.asm             |Banked RAM management     |                       | 0%           |
|docs/                          |Documentation/Manual      |                       | 5%           |

# Notes

## PS/2 Keyboard driver

- The keyboard driver queries the SMC for a key code every IRQ
- The key code is converted by the driver to an X16 ISO character (ISO 8859-15/Latin 9) and stored in a ring buffer
- When you read from the driver, it returns the next character from the ring buffer
- Why not VT100 encoding? It is just too much overhead for the 65C02 CPU. There is a risk that the system
would become sluggish if all input/output had to go through a VT100 parser. Support for VT100, or a subset thereof,
could be implemented in a serial or network driver.

## Terminal

- The terminal prints X16 ISO characters
- The driver is responsible for handling all X16 control codes. It is not
to interpret user input or execute commands.
- The terminal is responsible for showing a blinking cursor. The cursor blinking
is IRQ driven.
- The cursor is probably best implemented by switching background and foreground
colors at the current screen location. That way we don't need reversed variants
of all characters.

## Font

We should avoid copying the Commodore font, even though in 
many countries you can't claim copyright to bitmap fonts. There is a simple
python tool in the project that can be used to draw characters.

## Shell

The shell is the main system main loop.

The main loop reads input from STDIN and writes it to STDOUT. It is responsible for
- Reading input from STDIN
- Interpreting the input and executing commands or loading and starting program files
- Writing output to STDOUT

The shell could support a subset of the Unix terminal commands, such as ls, rm, mv, cd, mkdir and rmdir.
It could also have a command to start BASIC, if that is present in ROM.

An alternative approach is that a ROM resident BASIC is always running. The shell would in that case
only drive an X16/C64 like screen editor, while BASIC interprets all commands.

The exact function of the shell needs to be determined.

## SD card

The SD card driver works with the built-in SD card.

We can copy X16's open source FAT32 library. The SD card driver should talk directly
to the FAT32 library. 

The X16 ROM has a compatibility DOS layer that we do not need, and which would
create some unnecessary overhead.

