const std = @import("std");
const FileSource = std.build.FileSource;
const Mode = std.builtin.OptimizeMode;

const EXAMPLES = [_][]const u8{
    "arc",
    "arc_negative",
    "bezier",
    "cairoscript",
    "clip",
    "clip_image",
    "compositing",
    "curve_rectangle",
    "curve_to",
    "dash",
    "ellipse",
    "fill_and_stroke2",
    "fill_style",
    "glyphs",
    "gradient",
    "grid",
    "group",
    "image",
    "image_pattern",
    "mask",
    "multi_segment_caps",
    "pango_simple",
    "pythagoras_tree",
    "rounded_rectangle",
    "save_and_restore",
    "set_line_cap",
    "set_line_join",
    "sierpinski",
    "singular",
    "spiral",
    "spirograph",
    "surface_image",
    "surface_pdf",
    "surface_svg",
    "surface_xcb",
    "text",
    "text_align_center",
    "text_extents",
    "three_phases",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // b.verbose = true;
    // b.verbose_cimport = true;
    // b.verbose_link = true;

    const cairo_mod = b.addModule("cairo", .{
        .root_source_file = b.path("src/cairo.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cairo = b.addLibrary(.{
        .name = "cairo",
        .root_module = cairo_mod,
    });
    cairo_mod.linkSystemLibrary("cairo", .{});
    cairo_mod.linkSystemLibrary("pango", .{});

    const xcb_mod = b.addModule("xcb", .{
        .root_source_file = b.path("src/xcb.zig"),
        .target = target,
        .optimize = optimize,
    });

    const xcb = b.addLibrary(.{
        .name = "xcb",
        .root_module = xcb_mod,
    });
    xcb_mod.linkSystemLibrary("xcb", .{});

    const pangocairo_mod = b.addModule("pangocairo", .{
        .root_source_file = b.path("src/pangocairo.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pangocairo = b.addLibrary(.{
        .name = "pangocairo",
        .root_module = pangocairo_mod,
    });

    b.installArtifact(cairo);
    b.installArtifact(xcb);
    b.installArtifact(pangocairo);

    // pangocairo_mod.linkSystemLibrary("pangocairo", .{});
    // pangocairo_mod.addIncludePath(.{ .cwd_relative = "/usr/include/pango-1.0" });

    const test_all_modes_step = b.step("test", "Run all tests in all modes.");
    inline for ([_]Mode{ Mode.Debug, Mode.ReleaseFast, Mode.ReleaseSafe, Mode.ReleaseSmall }) |test_mode| {
        const mode_str = comptime modeToString(test_mode);
        const name = "test-" ++ mode_str;
        const desc = "Run all tests in " ++ mode_str ++ " mode.";
        const test_mod = b.createModule(.{
            .root_source_file = b.path("src/pangocairo.zig"),
            .target = target,
            .optimize = test_mode,
            .link_libc = true,
        });

        const tests = b.addTest(.{
            .root_module = test_mod,
        });
        // tests.setNamePrefix(mode_str ++ " ");
        test_mod.linkSystemLibrary("xcb", .{});
        test_mod.linkSystemLibrary("pango", .{});
        test_mod.linkSystemLibrary("cairo", .{});
        test_mod.linkSystemLibrary("pangocairo", .{});
        const test_step = b.step(name, desc);
        test_step.dependOn(&tests.step);
        test_all_modes_step.dependOn(test_step);

        tests.root_module.addImport("cairo", cairo.root_module);

        if (shouldIncludeXcb(name)) {
            tests.root_module.addImport("xcb", xcb.root_module);
        }
        if (shouldIncludePango(name)) {
            tests.root_module.addImport("pangocairo", pangocairo.root_module);
        }
    }

    // const examples_step = b.step("examples", "Build all examples");
    inline for (EXAMPLES) |name| {
        const example = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples" ++ std.fs.path.sep_str ++ name ++ ".zig"),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        example.root_module.addImport("cairo", cairo.root_module);

        if (shouldIncludeXcb(name)) {
            example.root_module.addImport("xcb", xcb.root_module);
        }
        if (shouldIncludePango(name)) {
            example.root_module.addImport("pangocairo", pangocairo.root_module);
        }
        example.root_module.linkSystemLibrary("cairo", .{});
        example.root_module.linkSystemLibrary("pango", .{});
        if (shouldIncludeXcb(name)) {
            example.root_module.linkSystemLibrary("xcb", .{});
        }
        example.root_module.linkSystemLibrary("pangocairo", .{});
        // b.installArtifact(example);
        // example.install(); // uncomment to build ALL examples (it takes ~2 minutes)
        // examples_step.dependOn(&example.step);

        const run_cmd = b.addRunArtifact(example);
        run_cmd.step.dependOn(b.getInstallStep());
        const desc = "Run the " ++ name ++ " example";
        const run_step = b.step(name, desc);
        run_step.dependOn(&run_cmd.step);
    }

    // b.default_step.dependOn(test_all_modes_step);
}

fn modeToString(mode: Mode) []const u8 {
    return switch (mode) {
        Mode.Debug => "debug",
        Mode.ReleaseFast => "release-fast",
        Mode.ReleaseSafe => "release-safe",
        Mode.ReleaseSmall => "release-small",
    };
}

fn shouldIncludePango(comptime name: []const u8) bool {
    var b = false;
    if (name.len > 6) {
        b = std.mem.eql(u8, name[0..6], "pango_");
    }
    return b;
}

fn shouldIncludeXcb(comptime name: []const u8) bool {
    return std.mem.eql(u8, name, "surface_xcb");
}
