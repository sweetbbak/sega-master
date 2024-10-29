const std = @import("std");

pub const DISPLAY_WIDTH: u32 = 256;
pub const DISPLAY_HEIGHT: u32 = 192;
pub const DISPLAY_WIDTH_LOG2: u32 = 8;
pub const DISPLAY_SIZE: u32 = DISPLAY_WIDTH * DISPLAY_HEIGHT;
pub const BORDER_LEFT_RIGHT: u32 = 64;
pub const BORDER_TOP_BOTTOM: u32 = 48;
pub const SCREEN_WIDTH: u32 = DISPLAY_WIDTH + BORDER_LEFT_RIGHT * 2;
pub const SCREEN_HEIGHT: u32 = DISPLAY_HEIGHT + BORDER_TOP_BOTTOM * 2;

pub const DisplayData = [DISPLAY_WIDTH * DISPLAY_HEIGHT]u8;

pub const PaletteValue = struct {
    index: u8,
    r: u8,
    g: u8,
    b: u8,
};

// Interface for rendering backend
pub const DisplayLoop = struct {
    pub fn Display() !void {
        // Implementation here
    }

    pub fn WritePalette() !void {
        // Implementation here
    }

    pub fn UpdateBorder() !void {
        // Implementation here
    }
};
