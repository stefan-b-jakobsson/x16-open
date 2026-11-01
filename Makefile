AS = ca65
LD = ld65

ASFLAGS += -I include
ASFLAGS += -g
ASFLAGS += --cpu 65SC02

BUILD_DIR = build
CONF_DIR = config
report := $(subst /,_,$(target))

# Common resources
#COMMON_DEPS = \
#	include/io.inc

# Kernal resources
KERNEL_SOURCES = \
	kernel/drivers/petscii.asm \
	kernel/drivers/ps2kbd.asm \
	kernel/drivers/terminal.asm \
	kernel/ramcode/jsrfar.asm \
	kernel/sys/device.asm \
	kernel/sys/irq.asm \
	kernel/sys/nmi.asm \
	kernel/sys/reset.asm \
	kernel/sys/vectors.asm \
	kernel/sys/file.asm

BANK_BINS = \
	$(BUILD_DIR)/kernel.bin \

KERNEL_OBJS = $(addprefix $(BUILD_DIR)/, $(KERNEL_SOURCES:.asm=.o))

# Wrapper for findsymbols that escapes the output and guards against non-zero exit codes
define findsymbols
$(strip \
	$(shell ${BUILD_DIR}/../findsymbols $(1) $(2)) \
	$(if \
		$(filter 0,$(firstword $(.SHELLSTATUS) 0)),, \
		$(error findsymbols failed with exit code $(.SHELLSTATUS)) \
	)
)
endef

# Targets
all: $(BUILD_DIR)/rom.bin

clean:
	rm -r build

# Combine all banks to one bin file
$(BUILD_DIR)/rom.bin: $(BANK_BINS)
	cat $(BANK_BINS) > $@

# Assemble bank
$(BUILD_DIR)/%.o: %.asm
	@mkdir -p $$(dirname $@)
	$(AS) $(ASFLAGS) $< -o $@ -l $(BUILD_DIR)/$(subst /,_,$@).lst

$(BUILD_DIR)/%.o: %.s
	@mkdir -p $$(dirname $@)
	$(AS) $(ASFLAGS) $< -o $@ -l $(BUILD_DIR)/$(subst /,_,$@).lst

# Make bank 0: ROM
$(BUILD_DIR)/kernel.bin: $(KERNEL_OBJS) $(CONF_DIR)/kernel.cfg $(CONF_DIR)/ram.inc
	@mkdir -p $$(dirname $@)
	cc65 -E -o $(BUILD_DIR)/kernel.cfg $(CONF_DIR)/kernel.cfg
	$(LD) -C $(BUILD_DIR)/kernel.cfg $(KERNEL_OBJS) -o $@ -Ln $(BUILD_DIR)/kernel.sym -m $(BUILD_DIR)/kernel.map
