const std = @import("std");
const vdp = @import("vdp.zig");
const z80 = @import("z80");
const memory = @import("mem.zig");
const ports = @import("port.zig");

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

    const buf = try file.readToEndAlloc(alloc, stat.size+1);
    return buf;
}

pub fn LoadROM(sms: *SMS, fileName: []const u8) !void {
    std.debug.print("Reading from file {s}\n", .{fileName});
    var data = try readROM(fileName);

    const a = std.heap.ArenaAllocator;
    const alloc = a.allocator();
    defer a.deinit();

    const size = data.len;
    const numROMBanks = size / PAGE_SIZE;
    
    sms.memory.romBanks = try mem.alloc([]u8, numROMBanks);
    std.debug.print("Found {d} ROM banks\n", .{numROMBanks});

    for (sms.memory.romBanks) |*bank| {
        bank.* = try mem.alloc(u8, PAGE_SIZE);
        
        var j: usize = 0;
        while (j < PAGE_SIZE) : (j += 1) {
            // bank.[j] = data[(@intCast(usize, @divTrunc(i, PAGE_SIZE)) * PAGE_SIZE) + j];
            bank.[j] = data[(@divTrunc(i, PAGE_SIZE)) * PAGE_SIZE) + j];
        }
    }

    for (sms.memory.pages) |*page| {
        page.* = @enumToInt(@mod(i, numROMBanks));
    }
    sms.memory.romPageMask = @enumToInt(numROMBanks - 1);
    sms.memory.maskedPage0 = sms.memory.pages[0] & sms.memory.romPageMask;
    sms.memory.maskedPage1 = sms.memory.pages[1] & sms.memory.romPageMask;
    sms.memory.maskedPage2 = sms.memory.pages[2] & sms.memory.romPageMask;

    sms.memory.romBank0 = try mem.alloc(u8, PAGE_SIZE);
    defer sms.memory.romBank0.deinit();
    
    mem.copy(u8, sms.memory.romBank0, sms.memory.romBanks[sms.memory.maskedPage0]);
}

// pub fn loadROM(data: []const u8) void {
//     const len = data.len;
//     _ = len; // autofix
// }
