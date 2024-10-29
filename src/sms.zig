const std = @import("std");
const vdp = @import("vdp.zig");
const z80 = @import("z80");
const memory = @import("mem.zig");
const ports = @import("port.zig");
const display = @import("display.zig");

var hblankcount = 0;

// Number of T-states per frame
const TStatesPerFrame = 227;
const PAGE_SIZE = 0x4000;

const Joypad = enum {
    JOYPAD_DOWN,
    JOYPAD_UP,
};

pub const SMS = struct {
    cpu: *z80.CPU,
    vdp: *z80.CPU,
    memory: *memory.Memory,
    ports: *ports.Ports,
    joystick: u8,
    paused: bool,
};

pub fn readROM(path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();

    const a = std.heap.ArenaAllocator;
    const alloc = a.allocator();
    defer a.deinit();

    const buf = try file.readToEndAlloc(alloc, stat.size + 1);
    return buf;
}

pub fn LoadROM(sms: *SMS, fileName: []const u8) !void {
    std.debug.print("Reading from file {s}\n", .{fileName});
    const data = try readROM(fileName);

    const a = std.heap.ArenaAllocator;
    const alloc = a.allocator();
    defer a.deinit();

    const size = data.len;
    const numROMBanks = size / PAGE_SIZE;

    sms.memory.rom_banks = try alloc.alloc([]u8, numROMBanks);
    std.debug.print("Found {d} ROM banks\n", .{numROMBanks});

    for (sms.memory.rom_banks, 0..) |*bank, i| {
        bank.* = try alloc.alloc(u8, PAGE_SIZE);

        var j: usize = 0;
        while (j < PAGE_SIZE) : (j += 1) {
            sms.memory.rom_banks[i][j] = data[(i * PAGE_SIZE) + j];
        }
    }

    for (sms.memory.pages, 0..) |*page, i| {
        page.* = @mod(i, numROMBanks);
    }

    sms.memory.rom_page_mask = (numROMBanks - 1);
    sms.memory.masked_page0 = sms.memory.pages[0] & sms.memory.rom_page_mask;
    sms.memory.masked_page1 = sms.memory.pages[1] & sms.memory.rom_page_mask;
    sms.memory.masked_page2 = sms.memory.pages[2] & sms.memory.rom_page_mask;

    sms.memory.rom_bank0 = try alloc.alloc(u8, PAGE_SIZE);
    @memcpy(sms.memory.rom_bank0, sms.memory.rom_banks[sms.memory.masked_page0]);
}

// cycles == tstates
pub fn render_frame(sms: *SMS, fileName: []const u8) display.DisplayData {
    _ = fileName; // autofix
    sms.vdp.status = 0;
    while ((sms.vdp.status & 2) == 0) {
        sms.cpu.cycles;
    }
}
