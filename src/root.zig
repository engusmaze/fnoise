const std = @import("std");

fn Vec(len: comptime_int) type {
    return @Vector(len, f32);
}
fn IVec(len: comptime_int) type {
    return @Vector(len, i32);
}
fn UVec(len: comptime_int) type {
    return @Vector(len, u32);
}

inline fn lerp(a: anytype, b: anytype, t: anytype) @TypeOf(a, b, t) {
    @setFloatMode(.optimized);
    const T = @TypeOf(a, b, t);
    return @mulAdd(T, b - a, t, a);
}

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
    fn get_f32(self: *Self) f32 {
        return @as(f32, @bitCast(@as(u32, @truncate(self.next())) >> 9 | 0x3f800000)) + -1.0;
    }
    fn shuffle(self: *Self, comptime T: type, arr: []T) void {
        var i = arr.len;
        while (i > 0) {
            i -= 1;
            std.mem.swap(T, &arr[i], &arr[@as(usize, @truncate(self.next())) % (i + 1)]);
        }
    }
};

pub fn Noise(dimensions: comptime_int, octaves: comptime_int, freq_arr: [octaves]u32, influences: [octaves]u32) type {
    return struct {
        const V = Vec(dimensions);
        const I = IVec(dimensions);
        const U = UVec(dimensions);

        const FreqV = Vec(octaves);
        const FreqI = IVec(octaves);
        const FreqU = UVec(octaves);

        const freq: FreqU = freq_arr[0..octaves].*;
        const freqScale: FreqV = @as(FreqV, @splat(1.0)) / @as(FreqV, @floatFromInt(freq));

        const scales: FreqV = result: {
            var influence_sum: u32 = 0;
            for (influences) |i| {
                influence_sum += i;
            }
            const sum = @as(f32, @floatFromInt(influence_sum));
            var values: FreqV = undefined;
            for (0..octaves) |o| {
                values[o] = @as(f32, @floatFromInt(influences[o])) / sum;
            }
            break :result values;
        };

        const hashing_values: U = ([_]u32{ 3099299701, 1699318553, 3785370593, 4056556871, 2890344139, 2782136641 })[0..dimensions].*;

        const root = @sqrt(@as(f32, @floatFromInt(dimensions)));
        fn normalize(v: V) V {
            return v / @as(V, @splat(root / @sqrt(@reduce(.Add, v * v))));
        }

        const directions = result: {
            @setEvalBranchQuota(10000);
            var rand = Rand.new(69);
            var values: [dimensions][256]f32 = undefined;
            for (0..256) |i| {
                var dir: V = undefined;
                for (0..dimensions) |j| {
                    dir[j] = rand.get_f32() * 2.0 - 1.0;
                }
                dir = normalize(dir);
                for (0..dimensions) |d| {
                    values[d][i] = dir[d];
                }
            }
            break :result values;
        };

        inline fn grad(pos: [dimensions]FreqU, delta: [dimensions]FreqV) FreqV {
            var hash: FreqU = @splat(0);
            inline for (0..dimensions) |d| {
                hash ^= pos[d];
            }
            var direction: [dimensions]FreqV = undefined;
            inline for (0..dimensions) |d| {
                var read: FreqV = undefined;
                for (0..octaves) |f| {
                    read[f] = directions[d][hash[f]];
                }
                direction[d] = read;
            }
            inline for (0..dimensions) |d| {
                direction[d] = direction[d] * delta[d];
            }
            var gradient: FreqV = undefined;
            inline for (0..dimensions) |d| {
                gradient += direction[d];
            }
            return gradient;
        }
        inline fn gradReduce(current: i32, comptime mask: [dimensions]bool, global_0: [dimensions]FreqU, global_1: [dimensions]FreqU, local_0: [dimensions]FreqV, local_1: [dimensions]FreqV, smooth: [dimensions]FreqV) FreqV {
            if (current < dimensions) {
                comptime var new_mask = mask;
                new_mask[current] = true;
                const a = gradReduce(current + 1, new_mask, global_0, global_1, local_0, local_1, smooth);
                new_mask[current] = false;
                const b = gradReduce(current + 1, new_mask, global_0, global_1, local_0, local_1, smooth);
                return lerp(a, b, smooth[current]);
            } else {
                var pos: [dimensions]FreqU = undefined;
                inline for (0..dimensions) |d| {
                    pos[d] = (if (mask[d]) global_0 else global_1)[d];
                }
                var delta: [dimensions]FreqV = undefined;
                inline for (0..dimensions) |d| {
                    delta[d] = (if (mask[d]) local_0 else local_1)[d];
                }
                return grad(pos, delta);
            }
        }

        pub fn perlin(pos: U) f32 {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);

            var global_0: [dimensions]FreqU = undefined;
            inline for (0..dimensions) |d| {
                global_0[d] = @as(FreqU, @splat(pos[d])) / freq;
            }
            inline for (0..dimensions) |d| {
                global_0[d] *%= @splat(hashing_values[d]);
            }
            var global_1: [dimensions]FreqU = undefined;
            inline for (0..dimensions) |d| {
                global_1[d] = global_0[d] +% @as(FreqU, @splat(hashing_values[d]));
            }
            inline for (0..dimensions) |d| {
                global_0[d] >>= @splat(24);
            }
            inline for (0..dimensions) |d| {
                global_1[d] >>= @splat(24);
            }

            var local_i: [dimensions]FreqU = undefined;
            inline for (0..dimensions) |d| {
                local_i[d] = @as(FreqU, @splat(pos[d])) % freq;
            }
            var local_0: [dimensions]FreqV = undefined;
            inline for (0..dimensions) |d| {
                local_0[d] = @as(FreqV, @floatFromInt(local_i[d])) * freqScale;
            }
            var local_1: [dimensions]FreqV = undefined;
            inline for (0..dimensions) |d| {
                local_1[d] = local_0[d] - @as(FreqV, @splat(1));
            }

            var smooth: [dimensions]FreqV = undefined;
            inline for (0..dimensions) |d| {
                const value = local_0[d];
                smooth[d] = value * value * (@as(FreqV, @splat(3)) - @as(FreqV, @splat(2)) * value);
            }

            return @reduce(.Add, gradReduce(0, undefined, global_0, global_1, local_0, local_1, smooth) * scales);
        }
    };
}
