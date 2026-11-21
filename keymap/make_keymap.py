"""
*****************************************************************************
Copyright 2026 Stefan Jakobsson

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
   this list of conditions and the following disclaimer in the documentation 
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
POSSIBILITY OF SUCH DAMAGE.
*****************************************************************************
"""

import klc_lib as klc
import os

# Keyboard Layout Table
#
# Address   Size    Description
# a000	    128	    Regular keys
# a080	    128	    Shift + keys
# a100	    128	    Control + keys
# a180	    128	    Alt + keys
# a200	    128	    AltGr + keys
# a280	    128     Shift + AltGr + keys
# a300	     24	    Dead keys: base key number
# a318	     24	    Dead keys: base key modifier
# a330	     24	    Dead keys: second key and output char index
# a348	    160	    Dead keys: second key (char value)
# a3e8	    160	    Dead keys: output char
# a488	     32	    Caps lock flags (regular mode)
# a4a8	     32	    Caps lock flags (AltGr mode)
# a4c8        1     Dead key count (base keys)
# a4c9        1     AltGr key flag
# a4ca	     38	    Reserved
# a4f0	     16	    Layout name, null-terminated
# Sum	   1280	bytes
#
# Further notes:
#
# 1. The tables at a000-a2ff holds the Latin9 encoded value
#    of key + modifier combinations. The IBM key number is
#    used as index into these tables.
# 
# 2. All dead keys are set to 0 in the tables at a000-a2ff.
#
# 3. Dead key combinations are stored in the tables at
#    a300-a487. A dead key combination consists of a
#    base key and modifier state, and one or more second keys 
#    and for each of the second keys, an output character.
#
#    The key number of the base key is stored in the table
#    at a300. The modifier key state is stored in the the 
#    table at a318.
#
#    The table at a330 holds the first index into the table
#    of second keys (a348) and the output char table (a3e8) for
#    each dead key. The last index points to the end of the
#    tables + 1.
#
#    The layout table supports max 23 base keys, and max
#    160 second keys.
#
#    The number of dead base keys is stored in a4c8.
# 
# 4. There are two Caps Lock tables. Each holds bit flags,
#    one for each key number, that indicates whether or
#    not Caps Lock affects the key number in regular mode
#    or AltGr mode. If AltGr is not present, pressing the 
#    right Alt key is the same as pressing the left Alt key.
#
# 5. The AltGr flag at a4c9 is 0 if the AltGr key is not
#    present in the current layout, and not 0 if it is
#    present.
#
# 6. The layout display name is stored at a4f0. The
#    string is null-terminated.


# Special keys in all modifier states
special_all = {
    # F-keys
    0x70: 0x85,  # F1
    0x71: 0x89,  # F2
    0x72: 0x86,  # F3
    0x73: 0x8A,  # F4
    0x74: 0x87,  # F5
    0x75: 0x8B,  # F6
    0x76: 0x88,  # F7
    0x77: 0x8C,  # F8
    0x78: 0x10,  # F9
    0x79: 0x15,  # F10
    0x7A: 0x16,  # F11
    0x7B: 0x17,  # F12
    
    # Esc and Menu
    0x6E: 0x1B,  # Esc
    0x41: 0x06,  # Menu

    # Numpad
    0x63: 0x30,  # '0'
    0x5D: 0x31,  # '1'
    0x62: 0x32,  # '2'
    0x67: 0x33,  # '3'
    0x5C: 0x34,  # '4'
    0x61: 0x35,  # '5'
    0x66: 0x36,  # '6'
    0x5B: 0x37,  # '7'
    0x60: 0x38,  # '8'
    0x65: 0x39,  # '9'
    0x64: 0x2A,  # '*'
    0x69: 0x2D,  # '-'
    0x6A: 0x2B,  # '+'
    0x68: 0x2E,  # '.'
    0x5F: 0x2F,  # '/'
    0x6C: 0x0D,  # numpad Enter

    # Extended keys
    0x53: 0x91,  # Up
    0x54: 0x11,  # Down
    0x4F: 0x9D,  # Left
    0x59: 0x1D,  # Right
    0x55: 0x82,  # Page Up
    0x56: 0x02,  # Page Down
    0x4B: 0x94,  # Insert
    0x4C: 0x19,  # Delete
    0x7E: 0x03,  # Break
}

# Special keys in regular mode
special_reg = {
    0x0F: 0x14,  # Backspace
    0x10: 0x09,  # TAB
    0x2B: 0x0D,  # Enter
    0x3D: 0x20,  # Space
    0x50: 0x13,  # Home
    0x51: 0x04,  # End
}

# Special keys in shift mode
special_shft = {
    0x0F: 0x94,  # Shift-Backspace = Insert
    0x10: 0x18,  # Shift-TAB
    0x2B: 0x8D,  # Shift-Enter
    0x3D: 0xA0,  # Shift-Space
    0x50: 0x93,  # Shift-Home = CLR
    0x51: 0x84,  # Shift-End
}

# Special keys in ctrl mode
special_ctrl = {
    0x02: 0x90,  # Ctrl+1  BLACK
    0x03: 0x05,  # Ctrl+2  WHITE
    0x04: 0x1C,  # Ctrl+3  RED
    0x05: 0x9F,  # Ctrl+4  CYAN
    0x06: 0x9C,  # Ctrl+5  PURPLE
    0x07: 0x1E,  # Ctrl+6  GREEN
    0x08: 0x1F,  # Ctrl+7  BLUE
    0x09: 0x9E,  # Ctrl+8  YELLOW
    0x0A: 0x12,  # Ctrl+9  REVERSE_ON
    0x0B: 0x92,  # Ctrl+0  REVERSE_OFF
}

# Special keys in alt mode
special_alt = {
    0x02: 0x81,  # Alt+1  ORANGE
    0x03: 0x95,  # Alt+2  BROWN
    0x04: 0x96,  # Alt+3  LIGHT_RED
    0x05: 0x97,  # Alt+4  DARK_GRAY
    0x06: 0x98,  # Alt+5  MIDDLE_GRAY
    0x07: 0x99,  # Alt+6  LIGHT_GREEN
    0x08: 0x9A,  # Alt+7  LIGHT_BLUE
    0x09: 0x9B,  # Alt+8  LIGHT_GRAY
}

# Helper function that converts modifier state from klc to Kernel format
def convert_modifier(modifier: int):
    if modifier == 1:
        # Shift
        return 1  
    elif modifier == 2:
        # Control
        return 2
    elif modifier == 6:
        # AltGr
        return 8
    elif modifier == 7:
        # Shift + AltGr
        return 9
    else:
        # No modifier
        return 0

# Helper function that pads an array to a specified length
def pad_array(a: list[int], l: int):
    if len(a) < l:
        return a + [0]*(l-len(a))
    else:
        raise Exception("Input array length too long")

# Main worker function that takes a klc file and returns a keyboard layout table
# formatted as expected by the Kernel
def kbd_table(path: str):
    # Parse layout file
    kb = klc.parse_klc(path)

    # Prepare output buffers
    keys_reg = [0] * 128
    keys_shft = [0] * 128
    keys_ctrl = [0] * 128
    keys_alt = [0] * 128
    keys_altgr = [0] * 128
    keys_shft_altgr = [0] * 128

    deadkeys_scancode = []
    deadkeys_modifier = []
    deadkeys_index = []
    deadkeys_key2 = []
    deadkeys_output = []

    caps_reg = [0] * 32
    caps_altgr = [0] * 32
    altgrflag = [0]
    deadkeycount = [0]
    reserved = [0] * 39
    name = []

    # Set name, limited to first 15 characters, omitting the leading quote
    for c in list(kb.header.name[1:16]):
        name.append(klc.to_latin9(c))

    for l in kb.layout:
        # Add printable Latin9 chars, ignore dead keys
        for modifier in [0, 1, 6, 7]:
            if modifier in l.chars.keys() and not l.deads[modifier]:
                if modifier == 0:
                    keys_reg[l.scancode] = klc.to_latin9(l.chars[modifier])
                elif modifier == 1:
                    keys_shft[l.scancode] = klc.to_latin9(l.chars[modifier])
                elif modifier == 6:
                    keys_altgr[l.scancode] = klc.to_latin9(l.chars[modifier])
                    altgrflag[0]=1
                elif modifier == 7:
                    keys_shft_altgr[l.scancode] = klc.to_latin9(l.chars[modifier])
                    altgrflag[0]=1

        # Update Caps Lock tables
        if l.cap in [1, 5]:
            caps_reg [l.scancode//8] |= 1 << (l.scancode % 8)
        
        if l.cap in [4, 5]:
            caps_altgr [l.scancode//8] |= 1 << (l.scancode % 8)

        # Make dead keys tables
        for modifier in l.deads.keys():
            if l.deads[modifier]:
                # Restore counter and set start index in combo and output tables
                count = 0
                index = len(deadkeys_key2)

                # Add second key and output char to key2 and output tables, after Latin9 conversion
                for dk in kb.deadkeys:
                    if l.chars[modifier] == dk.base:
                        for ck in dk.combos.keys():
                            key2 = klc.to_latin9(ck)
                            output = klc.to_latin9(dk.combos[ck])
                            if key2 > 0 and output > 0:
                                # Both the second key and the output char available in Latin9
                                deadkeys_key2.append(key2)
                                deadkeys_output.append(output)
                                count += 1
                            elif output > 0:
                                # Warning: The output char is available in Latin9, but not the second key
                                print("Warning: Unreachable dead key combination in " + path + " ", end="")
                                print("Scancode: " + str(l.scancode), end=". ")
                                print("Modifier: " + str(modifier), end=". ")
                                print("Second key: " + str(ck), end=". ")
                                print("Output char: " + dk.combos[ck])
                
                if count > 0:
                    # One or more dead keys were added: update scancode, modifier, and index tables
                    deadkeys_scancode.append(l.scancode)
                    deadkeys_modifier.append(convert_modifier(modifier))
                    deadkeys_index.append(index)
    
    # Add index to end of key2 and output tables
    deadkeys_index.append(len(deadkeys_key2))

    # Update dead key count
    deadkeycount[0] = len(deadkeys_scancode)

    # Pad arrays to fixed lengths
    deadkeys_scancode = pad_array(deadkeys_scancode, 24)
    deadkeys_modifier = pad_array(deadkeys_modifier, 24)
    deadkeys_index = pad_array(deadkeys_index, 24)
    deadkeys_key2 = pad_array(deadkeys_key2, 160)
    deadkeys_output = pad_array(deadkeys_output, 160)
    name = pad_array(name, 16)

     # Add special keys
    for key in special_all.keys():
        keys_reg[key] = special_all[key]
        keys_shft[key] = special_all[key]
        keys_altgr[key] = special_all[key]
        keys_shft_altgr[key] = special_all[key]
    
    for key in special_reg.keys():
        keys_reg[key] = special_reg[key]
    
    for key in special_shft.keys():
        keys_shft[key] = special_shft[key]

    for key in special_ctrl.keys():
        keys_ctrl[key] = special_ctrl[key]

    for key in special_alt.keys():
        keys_alt[key] = special_alt[key]

    # Make output buffer
    out = keys_reg + keys_shft + keys_ctrl + keys_alt + keys_altgr + keys_shft_altgr + deadkeys_scancode + deadkeys_modifier + deadkeys_index + deadkeys_key2 + deadkeys_output + caps_reg + caps_altgr + deadkeycount + altgrflag + reserved + name
    return out

def make_asm_file(asm_path:str, klc_path:str):
    # Get layout
    kb = klc.parse_klc(klc_path)
    id = os.path.basename(klc_path).split()[0]

    # Set local name, some needs adjustments
    locales = {}
    locales["99409"] = "en-US/ABC"
    locales["20409"] = "en-US/Int"
    locales["10409"] = "en-US/Dvorak"

    locale = kb.header.locale_name
    if id in locales.keys():
        locale = locales[id]

    # Create asm file
    f = open(asm_path, "w")
    f.write("; X16 Open Keyboard Table\n")
    f.write("; *** Auto-generated file ***\n\n")
    f.write("; Source:\t" + os.path.basename(klc_path) + "\n")
    f.write("; Locale:\t" + locale + "\n\n")
    f.write(".segment \"KBDMETA\"\n")
    f.write("\t.byte \"" + locale + "\"")
    for i in range(0,14-len(locale)):
        f.write(", 0")
    f.write("\n\t.word kbdtab_" + id + "\n\n")
    f.write(".segment \"KBDTABLES\"\n")
    f.write("kbdtab_" + id + ":\n")
    f.write("\t.incbin \"" + os.path.join("asm", id + ".lzsa") + "\"\n")
    f.close()

# main function: creates all keymap files
if __name__ == "__main__":
    # List of supported keyboard layouts
    layouts = [
        "99409", 
        "20409", 
        "809", 
        "41D", 
        "407", 
        "406", 
        "410", 
        "415", 
        "414", 
        "40E", 
        "40A", 
        "40B", 
        "416", 
        "405", 
        "40C", 
        "807", 
        "10409", 
        "425", 
        "80C", 
        "1009", 
        "40F", 
        "816", 
        "41A", 
        "41B", 
        "424", 
        "426", 
        "427",
    ]
    
    files = os.listdir("klc")
    for l in layouts:
        for f in files:
            if f.startswith(l + " ") and f.endswith(".klc"):
                # Construct paths
                f_klc = os.path.join("klc", f)
                f_bin = os.path.join("asm", l + ".bin")
                f_lzsa = os.path.join("asm", l + ".lzsa")
                f_asm = os.path.join("asm", l + ".asm")

                # Make layout .bin file
                out = kbd_table(f_klc)
                f2 = open(f_bin, "wb")
                f2.write(bytes(out))
                f2.close()

                # Make layout .asm file
                make_asm_file(f_asm, f_klc)

                # Compress .bin file using lzsa
                os.system("lzsa -f 2 -r --prefer-ratio \"" + f_bin + "\" \"" + f_lzsa + "\"")

                # Delete .bin file
                os.system("rm \"" + f_bin + "\"")
