const std = @import("std");
const zigimg = @import("zigimg");
const zimeg = @import("zimeg");
const fnoise = @import("fnoise");

const Time = zimeg.Time;
const Noise = fnoise.Noise;

const N = Noise(3, 4, .{ 32, 16, 8, 4 }, .{ 8, 4, 2, 1 });
// const N = Noise(2, 1, .{32}, .{32});

pub fn main() !void {
    // std.debug.print("{d}", .{NoiseChad(2, &.{ 16, 32 }).get(.{ 256, 123 })});

    const allocator = std.heap.page_allocator;
    var stdout = std.io.getStdOut().writer();

    const width = 512;
    const height = 512;

    const buffer = try allocator.alloc(u8, width * height * 8);
    defer allocator.free(buffer);

    var img = try zigimg.Image.create(allocator, width, height, .rgb24);
    defer img.deinit();

    const values = try allocator.alloc(f32, width * height);
    defer allocator.free(values);

    var z: u32 = 0;

    while (true) {
        const start = Time.now();
        for (values, 0..) |*value, i| {
            const x: u32 = @intCast(i % width);
            const y: u32 = @intCast(i / width);

            value.* = N.perlin(.{ x, y, z });
        }
        const end = Time.now();
        _ = try stdout.write("Done in: ");
        try end.since(start).print(stdout);
        _ = try stdout.write("\n");

        for (img.pixels.rgb24, values) |*pixel, value| {
            const val: u8 = @intFromFloat(value * 128.0 + 128.0);
            pixel.* = zigimg.color.Rgb24{ .r = val, .g = val, .b = val };
        }

        const bytes = try img.writeToMemory(buffer, .{ .qoi = .{} });
        var file = try std.fs.cwd().createFile("test.qoi", .{});
        try file.writer().writeAll(bytes);
        file.close();

        z += 1;
    }
    // try img.writeToFilePath("test.png", .{ .png = .{ .filter_choice = .{ .specified = .none } } });
}
