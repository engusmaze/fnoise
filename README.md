# FNoise

## Installation Steps:

### Adding the Library URL:

Use `zig fetch` command to save the library's URL and its hash to a `build.zig.zon` file.

```sh
zig fetch --save https://github.com/engusmaze/fnoise/archive/bd438da0b45b8979399d2ac7158cf9b933db6f1f.tar.gz
```

### Adding the Dependency:

After saving the library's URL, you need to make it importable by your code in the `build.zig` file. This involves specifying the dependency and adding it to an executable or library.

```zig
pub fn build(b: *std.Build) void {
    // ...
    const fnoise = b.dependency("fnoise", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("fnoise", fnoise.module("fnoise"));
}
```

### Importing the Library:

Once the dependency is specified in the `build.zig` file, you can import the library into your Zig code using the `@import` directive.

```zig
const fnoise = @import("fnoise");

const World = fnoise.Noise(3, 4, .{ 32, 16, 8, 4 }, .{ 8, 4, 2, 1 });
```