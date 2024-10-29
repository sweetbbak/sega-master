const std = @import("std");
const vdp = @import("vdp.zig");
const sms = @import("sms.zig");

const Ports = struct {
    sms: *sms.SMS,
    vdp: *vdp.Vdp,
    joystick: u8,

    pub fn ReadPort(ports: *Ports, address: u16) u8 {
        return ports.ReadPortInternal(address);
    }

    fn ReadPortInternal(ports: *Ports, address: u16) u8 {
        switch (address) {
            0x7E, 0x7F => return @as(u8, ports.vdp.get_line()),
            0xDC, 0xC0 => return ports.joystick,
            0xDD, 0xC1 => return @as(u8, ports.joystick >> 8),
            0xBE => return ports.vdp.readByte(),
            0xBD, 0xBF => return @as(u8, ports.vdp.readStatus()),
            0xDE, 0xDF => return 0, // Unknown use
            0xF2 => return 0, // YM2413
        }
        return 0;
    }

    pub fn WritePort(ports: *Ports, addr: u16, b: u8) void {    
        ports.WritePortInternal(addr, b, true);
    }

    pub fn WritePortInternal(ports: *Ports, address: u16, b: u8, contend: bool) void {
        _ = contend; // autofix
        switch (address) {
            0x3f => {
                var natbit: u8 = ((b >> 5) & 1);
                if ((b & 1) == 0) {
                    natbit = 1;
                }
                // ports.sms.joystick = (ports.sms.joystick & ~(1 << 6)) | @intCast(u32, natbit << 6);
                ports.sms.joystick = (ports.sms.joystick & ~(1 << 6)) | @as(u8, @intCast(natbit << 6));

                natbit = ((b >> 7) & 1);
                if ((b & 4) == 0) {
                    natbit = 1;
                }
                ports.sms.joystick = (ports.sms.joystick & ~(1 << 7)) | @as(u8, @intCast(natbit << 7));
            },
            0x7e, 0x7f => {
                // soundChip.poke(val);
            },
            0xbd, 0xbf => {
                ports.sms.vdp.write_addr(@as(u16, @intCast(b)));
            },
            0xbe => {
                ports.sms.vdp.writeByte(b);
            },
            0xde, 0xdf => {},
            0xf0, 0xf1, 0xf2 => {},
            else => {
                std.debug.print("Write to IO port {X}\n", address);
            },
        }
    }
};
