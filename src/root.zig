const std = @import("std");

const Vec2 = @Vector(2, f32);
const UVec2 = @Vector(2, u32);

const Rand = struct {
    rand: u64,
    const Self = @This();

    fn new(seed: u64) Self {
        return .{ .rand = seed };
    }
    fn next(self: *Self) u64 {
        self.rand +%= 12964901029718341801;
        var value = self.rand;
        value = value *% (149988720821803190 ^ value);
        return value ^ value >> 32;
    }
};

fn ComptimePerlin2D(comptime seed: u64) type {
    const lerp = std.math.lerp;

    comptime var rand = Rand.new(seed);

    const directions: [256]Vec2 = dirs: {
        @setEvalBranchQuota(100000);
        var vecs: [256]Vec2 = undefined;
        for (&vecs, 0..) |*vec, i| {
            const j = @as(f32, @floatFromInt(i)) / (256.0 / std.math.tau);
            vec.* = Vec2{ @cos(j), @sin(j) };
        }
        var i = vecs.len;
        while (i > 0) {
            i -= 1;
            const r = rand.next();
            std.mem.swap(Vec2, &vecs[i], &vecs[
                @as(usize, r) % (i + 1)
            ]);
        }
        break :dirs vecs;
    };

    return struct {
        inline fn grad(pos: UVec2, delta: Vec2) f32 {
            @setRuntimeSafety(false);
            @setFloatMode(.Optimized);
            const hash = pos[0] ^ pos[1];
            const dir = directions[hash] * delta;
            return dir[0] + dir[1];
        }
        fn get(comptime freq: u32, position: UVec2) f32 {
            @setRuntimeSafety(false);
            @setFloatMode(.Optimized);
            var pos_0 = position;
            const cell_i = pos_0 % @as(UVec2, @splat(freq));
            pos_0 /= @as(UVec2, @splat(freq));
            const cell_0 = @as(Vec2, @floatFromInt(cell_i)) / @as(Vec2, @splat(freq));
            const cell_1 = cell_0 - @as(Vec2, @splat(1));

            const smooth = cell_0 * cell_0 * (@as(Vec2, @splat(3)) - @as(Vec2, @splat(2)) * cell_0);

            const primes = UVec2{ 2534462113, 2396097287 };
            pos_0 *= primes;
            var pos_1 = pos_0 + primes;
            pos_0 >>= @splat(24);
            pos_1 >>= @splat(24);

            const h00 = grad(pos_0, cell_0);
            const h01 = grad(UVec2{ pos_0[0], pos_1[1] }, Vec2{ cell_0[0], cell_1[1] });
            const h0 = lerp(h00, h01, smooth[1]);
            const h10 = grad(UVec2{ pos_1[0], pos_0[1] }, Vec2{ cell_1[0], cell_0[1] });
            const h11 = grad(pos_1, cell_1);
            const h1 = lerp(h10, h11, smooth[1]);

            return lerp(h0, h1, smooth[0]);
        }
    };
}
