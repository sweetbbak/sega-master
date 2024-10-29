const std = @import("std");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

pub fn SMS() !void {
    const sixty_th: f64 = 1000/60; // milliseconds game loop
    const last_frame: f64 = 0;
    const not_quitting: bool = false;

    while (not_quitting) {
        const current_time = get_current_time();
        if (( last_frame + sixty_th ) <= current_time) {
            last_frame = current_time;
            // Update() // update function - draw to screen
        }
    }
}

pub fn main() !void {
    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(global.testOne, .{});
}
