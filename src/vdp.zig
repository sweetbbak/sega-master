const std = @import("std");
const z80 = @import("z80");
const Vdp = @This();
// const Vdp = struct {};

vram: []u8,
regs: []u8,
palette: []u8,
paletteR: []u8,
paletteG: []u8,
paletteB: []u8,
addr: u16,
addr_state: u16,
addr_latch: u16,
current_line: u16,
status: u8,
h_blank_counter: u8,
write_routine: *const fn (self: *Vdp, u8) void,
read_routine: *const fn (self: *Vdp) u8,

pub fn updateBorder(self: *Vdp) void {
    const borderIndex = 16 + (self.regs[7] & 0xF);
    _ = borderIndex; // autofix
    // trigger video border update SDL
}

pub fn write_addr(self: *Vdp, value: u16) void {
    if (self.addr_state == 0) {
        self.addr_state = 1;
        self.addr_latch = value;
    } else {
        self.addr_state = 0;
        switch (value >> 6) {
            0, 1 => {
                self.write_routine = self.writeRAM;
                self.read_routine = self.readRAM;
                self.add = self.addr_latch | ((value & 0x3F) << 8);
                return;
            },
            2 => {
                const regnum = value & 0xF;
                self.regs[regnum] = self.addr_latch;
                switch (regnum) {
                    7 => {
                        self.updateBorder();
                        return;
                    },
                    else => {
                        return;
                    },
                }
                return;
            },
            3 => {
                self.write_routine = self.write_palatte;
                self.read_routine = self.read_palatte;
                self.addr = self.addr_latch & 0x1F;
                return;
            },
            else => {
                return;
            },
        }
    }
}

pub fn writeRAM(self: *Vdp, value: u8) void {
    self.vram[self.addr] = value;
    self.addr = (self.addr + 1) & 0x3FFF;
}

pub fn readRAM(self: *Vdp) u8 {
    const result = self.vram[self.addr];
    self.addr = (self.addr + 1) & 0x1F;
    return result;
}

pub fn write_palette(self: *Vdp, val: u8) void {
    const r = val & 3;
    r |= r << 2;
    r |= r << 4;
    const g = (val >> 2) & 3;
    g |= g << 2;
    g |= g << 4;
    const b = (val >> 4) & 3;
    b |= b << 2;
    b |= b << 4;
    self.paletteR[self.addr] = r;
    self.paletteG[self.addr] = g;
    self.paletteB[self.addr] = b;

    // vdp.displayLoop.WritePalette() <- PaletteValue{byte(vdp.addr), byte(r), byte(g), byte(b)}
    self.palette[self.addr] = val;
    self.addr = (self.addr + 1) & 0x1f;

    // vdp.updateBorder()
    // return;
}

pub fn writeByte(self: *Vdp, val: u8) void {
    self.addrState = 0;
    self.write_routine(self, val);
}

pub fn readByte(self: *Vdp) u8 {
	self.addr_state = 0;
	return self.read_routine();
}

fn readPalette(self: *Vdp) u8 {
	const res = self.palette[self.addr];
	self.addr = (self.addr + 1) & 0x3fff;
	return res;
}

pub fn readStatus(self: *Vdp) u8 {
    const res = self.status;
    self.status &= 0x3f;
    return res;
}

pub fn findSprites(self: *Vdp, line: i32) [][]i32 {
    // const spriteInfo: i32 = @truncate(self.regs[5] & 0x7e) << 7;
    const spriteInfo: i32 = @truncate(self.regs[5] & 0x7e);
    spriteInfo = spriteInfo << 7;

    var active = try std.ArrayList([]i32).initCapacity(std.heap.page_allocator, 8);
    defer std.heap.page_allocator.deinit(active);

    const spriteHeight = if (self.regs[1] & 2 != 0) 16 else 8;
    for (0..64) |i| {
        const y = self.vram[spriteInfo + i];
        if (y == 208) break;
        if (y >= 240) y -= 256;
        if (line >= y and line < (y + spriteHeight)) {
            if (active.items.len == 8) {
                self.status |= 0x40; // Sprite overflow
                break;
            }
            active.append(.{self.vram[spriteInfo + 128 + i*2], self.vram[spriteInfo + 128 + i*2+1], y}) catch unreachable;
        }
    }
    return active.toOwnedSlice();
}

pub fn rasterizeBackground(self: *Vdp, lineAddr: i32, pixelOffset: u8, tileData: i32, tileDef: i32) void {
    const tileVal0 = self.vram[tileDef];
    const tileVal1 = self.vram[tileDef + 1];
    const tileVal2 = self.vram[tileDef + 2];
    const tileVal3 = self.vram[tileDef + 3];
    const paletteOffset = if (tileData & (1 << 11) != 0) 16 else 0;
    if (tileData & (1 << 9) != 0) {
        for (0..8) |_| {
            const index = ((tileVal0 & 1) | ((tileVal1 & 1) << 1) | ((tileVal2 & 1) << 2) | ((tileVal3 & 1) << 3)) + paletteOffset;
            if (index != 0) {
                self.displayData[lineAddr + @as(i32, @intCast(pixelOffset))] = index;
            }
            pixelOffset += 1;
            tileVal0 >>= 1;
            tileVal1 >>= 1;
            tileVal2 >>= 1;
            tileVal3 >>= 1;
        }
    } else {
        for (0..8) |_| {
            const index = (((tileVal0 & 128) >> 7) | ((tileVal1 & 128) >> 6) | ((tileVal2 & 128) >> 5) | ((tileVal3 & 128) >> 4)) + paletteOffset;
            if (index != 0) {
                self.displayData[lineAddr + @as(i32, @intCast(pixelOffset))] = index;
            }

            pixelOffset += 1;
            tileVal0 <<= 1;
            tileVal1 <<= 1;
            tileVal2 <<= 1;
            tileVal3 <<= 1;
        }
    }
}

pub fn clearBackground(self: *Vdp, lineAddr: i32, pixelOffset: u8) void {
    for (0..8) |_| {
        self.displayData[lineAddr + @as(i32, @intCast(pixelOffset))] = 0;
        pixelOffset += 1;
    }
}

pub fn rasterizeLine(allocator: *std.mem.Allocator, vdp: *Vdp, line: u32) void {
    _ = allocator; // autofix
    const line_addr: u32 = line;
    if (vdp.regs[1] & 64 == 0) {
        for (0..256) |i| {
            vdp.displayData[line_addr + i] = 0;
        }
        return;
    }

    const effective_line: u32 = line + @as(u32, vdp.regs[9]);
    if (effective_line >= 224) {
        effective_line -= 224;
    }

    const sprites = vdp.findSprites(line);
    const sprites_len = @as(usize, sprites.len);
    const sprite_base: u32 = if (vdp.regs[6] & 4 != 0) 0x2000 else 0;
    const pixel_offset: u32 = @as(u32, vdp.regs[8]) / 4;

    const name_addr: u32 = (@as(u32, vdp.regs[2]) << 10) & 0x3800 + (effective_line >> 3) << 6;
    const y_mod: u32 = effective_line & 7;
    const border_index: u32 = 16 + vdp.regs[7] & 0xf;

    for (0..32) |i| {
        const tile_data: u32 = @as(u32, vdp.vram[name_addr + i << 1]) | (@as(u32, vdp.vram[name_addr + i << 1 + 1]) << 8);
        const tile_num: u32 = tile_data & 511;
        const tile_def: u32 = tile_num << 5;
        if (tile_data & (1 << 10) != 0) {
            tile_def += 28 - (y_mod << 1);
        } else {
            tile_def += y_mod << 1;
        }

        vdp.clearBackground(line_addr, pixel_offset);

        if (tile_data & (1 << 12) == 0) {
            vdp.rasterizeBackground(line_addr, pixel_offset, tile_data, tile_def);
        }

        const saved_offset: u32 = pixel_offset;
        const x_pos: u32 = (i * 8 + vdp.regs[8]) & 0xff;

        for (0..8) |_| {
            var written_to: bool = false;
            for (0..sprites_len) |k| {
                const sprite = sprites[k];
                const offset: u32 = x_pos - sprite[0];
                if (offset < 0 or offset >= 8) continue;
                const sprite_line: u32 = line - sprite[2];
                const sprite_addr: u32 = sprite_base + sprite[1] << 5 + sprite_line << 2;
                const effective_bit: u32 = 7 - offset;
                const spr_val0: u32 = vdp.vram[sprite_addr];
                const spr_val1: u32 = vdp.vram[sprite_addr + 1];
                const spr_val2: u32 = vdp.vram[sprite_addr + 2];
                const spr_val3: u32 = vdp.vram[sprite_addr + 3];

                const index: u32 = ((spr_val0 >> (effective_bit)) & 1) |
                                   (((spr_val1 >> (effective_bit)) & 1) << 1) |
                                   (((spr_val2 >> (effective_bit)) & 1) << 2) |
                                   (((spr_val3 >> (effective_bit)) & 1) << 3);


                if (index == 0) continue;

                if (written_to) {
                    vdp.status |= 0x20;
                    break;
                }

                vdp.displayData[line_addr + @as(u32, pixel_offset)] = 16 + index;
                written_to = true;
            }
            x_pos += 1;
            pixel_offset += 1;
        }

        if (tile_data & (1 << 12) != 0) {
            vdp.rasterizeBackground(line_addr, saved_offset, tile_data, tile_def);
        }
    }

    if (vdp.regs[0] & (1 << 5) != 0) {
        for (0..8) |i| {
            vdp.displayData[line_addr + i] = border_index;
        }
    }
}

pub fn hblank(self: *Vdp) u8 {
    var needIrq: u8 = 0;
    const firstDisplayLine: u32 = 3 + 13 + 54;
    const pastEndDisplayLine: u32 = firstDisplayLine + 192;
    const endOfFrame: u32 = pastEndDisplayLine + 48 + 3;

    if (self.currentLine >= firstDisplayLine and self.currentLine < pastEndDisplayLine) {
        self.rasterizer.rasterizeLine(self.currentLine - firstDisplayLine);
        self.hBlankCounter -= 1;
        if (self.hBlankCounter < 0) {
            self.hBlankCounter = @as(u32, @intCast(self.regs[10]));
            self.status = self.status & 127;

            if ((self.regs[0] & 16) != 0) {
                needIrq |= 1;
            }
        }
    }

    self.currentLine += 1;
    if (self.currentLine == endOfFrame) {
        self.currentLine = 0;
        self.status |= 128;
        if ((self.regs[1] & 32) != 0) {
            needIrq |= 2;
        }
    }

    return needIrq;
}

pub fn reset(self: *Vdp) void {
    for (0x0000..0x4000) |i| {
        self.vram[i] = 0;
    }
    for (0..32) |i| {
        self.paletteR[i] = 0;
        self.paletteG[i] = 0;
        self.paletteB[i] = 0;
        self.palette[i] = 0;
    }
    for (0..16) |i| {
        self.regs[i] = 0;
    }
    for (2..6) |i| {
        self.regs[i] = 0xFF;
    }
    self.regs[6] = 0xFB;
    self.regs[10] = 0xFF;
    self.current_line = 0;
    self.status = 0;
    self.h_blank_counter = 0;
}

pub fn get_line(self: *Vdp) u16 {
    return (self.current_line - 64) & 0xFF;
}

pub fn dumpSprites(vdp: *Vdp) void {
    const spriteInfo: u8 = vdp.regs[5] & 0x7e;
    
    for (0..64) |i| {
        const y = vdp.vram[spriteInfo + i];
        const x = vdp.vram[spriteInfo + 128 + i * 2];
        const t = vdp.vram[spriteInfo + 128 + i * 2 + 1];
        
        std.debug.print("{d} x: {d}, y: {d}, t: {d}\n", .{i, x, y, t});
    }
}
