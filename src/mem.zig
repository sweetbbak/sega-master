const std = @import("std");
const z80 = @import("z80");

pub const Memory = struct {
    ram: [0x2000]u8,
    cart_ram: [0x8000]u8,
    pages: [4]u8,
    rom_banks: [][]u8,
    rom_bank0: []u8,
    rom_page_mask: u8,
    masked_page0: u8,
    masked_page1: u8,
    masked_page2: u8,
    ram_select_reg: u8,
    cpu: z80.CPU,

    inline fn _read(self: *Memory, addr: u16) u8 {
        return self.mem[addr];
    }

    fn read(self: *Memory, addr: u16) u8 {
        if (addr < 0x0400) {
            return self.rom_banks[0][addr];
        }
        if (addr < 0x4000) {
            return self.rom_bank0[addr];
        }
        if (addr < 0x8000) {
            return self.rom_banks[self.masked_page1][addr - 0x4000];
        }
        if (addr < 0xC000) {
            if ((self.ram_select_reg & 12) == 8) {
                return self.cart_ram[addr - 0x8000];
            } else if ((self.ram_select_reg & 12) == 12) {
                return self.cart_ram[addr - 0x4000];
            } else {
                return self.rom_banks[self.masked_page2][addr - 0x8000];
            }
        }
        if (addr < 0xE000) {
            return self.ram[addr - 0xC000];
        }
        if (addr < 0xFFFC) {
            return self.ram[addr - 0xE000];
        }

        switch (addr) {
            0xFFFC => {
                return self.ram_select_reg;
            },
            0xFFFD => {
                return self.pages[0];
            },
            0xFFFE => {
                return self.pages[1];
            },
            0xFFFF => {
                return self.pages[2];
            },
            else => {
                std.debug.panic("couldn't read memory addr: '{X}'", addr);
            },
        }

        return 0;
    }

    pub fn write(self: *Memory, addr: u16, value: u8) void {
        if (addr >= 0xFFFC) {
            switch (addr) {
                0xFFFC => {
                    self.ram_select_reg = value;
                    return;
                },
                0xFFFD => {
                    self.pages[0] = value;
                    self.masked_page0 = value & self.rom_page_mask;
                    @memcpy(self.rom_bank0, self.rom_banks[self.masked_page0]);
                    return;
                },
                0xFFFE => {
                    self.pages[1] = value;
                    self.masked_page1 = value & self.rom_page_mask;
                    return;
                },
                0xFFFF => {
                    self.pages[2] = value;
                    self.masked_page2 = value & self.rom_page_mask;
                    return;
                },
                else => {
                    std.debug.panic("couldn't read memory addr: '{X}'", addr);
                },
            }

            return;
        }

        if (addr < 0xC000) {
            return; // ignore ROM writes
        }

        self.ram[addr & 0x1FFF] = value;
    }

    // irq: *const fn (ptr: *anyopaque) u8,
    // /// Read from I/O.
    // in: *const fn (ptr: *anyopaque, port: u16) u8,
    // /// Write to I/O.
    // out: *const fn (ptr: *anyopaque, port: u16, value: u8) void,
    // /// Called when an interrupt routine is completed.
    // reti: *const fn (ptr: *anyopaque) void,

    // fulfill the Z80 interface read function
    fn interface(self: *Memory) z80.Interface {
        return z80.Interface.init(self, .{ .read = read });
    }
};
