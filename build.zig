const std = @import("std");

const Backend = enum {
    none,
    vulkan,
    d3d12,
    d3d11,
};

const enable_validation = true;
const enable_debug_names_and_annotations = true;
const target_backend: Backend = .vulkan;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_headers_dep = b.dependency("vulkan_headers", .{});
    const vma_dep = b.dependency("vma", .{});
    const nri_dep = b.dependency("nri", .{});

    const nri_lib = b.addStaticLibrary(.{
        .name = "nri",
        .target = target,
        .optimize = optimize,
    });

    nri_lib.defineCMacro("NRI_STATIC_LIBRARY", null);

    // if platform is linux
    nri_lib.defineCMacro("VK_USE_PLATFORM_XLIB_KHR", null);

    switch (target_backend) {
        .vulkan => {
            nri_lib.defineCMacro("NRI_ENABLE_VK_SUPPORT", "1");
        },
        .d3d12 => {
            nri_lib.defineCMacro("NRI_ENABLE_D3D12_SUPPORT", "1");
        },
        .d3d11 => {
            nri_lib.defineCMacro("NRI_ENABLE_D3D11_SUPPORT", "1");
        },
        .none => {
            nri_lib.defineCMacro("NRI_ENABLE_NONE_SUPPORT", "1");
        },
    }

    if (enable_debug_names_and_annotations) {
        nri_lib.defineCMacro("NRI_ENABLE_DEBUG_NAMES_AND_ANNOTATIONS", "1");
    }
    if (enable_validation) {
        nri_lib.defineCMacro("NRI_ENABLE_VALIDATION_SUPPORT", "1");
        nri_lib.addIncludePath(nri_dep.path("Source/Validation"));
    }

    nri_lib.addIncludePath(vma_dep.path("include"));
    nri_lib.addIncludePath(vulkan_headers_dep.path("include"));
    nri_lib.addIncludePath(nri_dep.path("Include"));
    nri_lib.addIncludePath(nri_dep.path("Source/Shared"));
    nri_lib.addIncludePath(nri_dep.path("Source/Creation"));
    nri_lib.addIncludePath(nri_dep.path("Source/VK"));

    const shared_src = [_][]const u8{
        "Shared/Shared.cpp",
    };

    const creation_src = [_][]const u8{
        "Creation/Creation.cpp",
    };

    const validation_src = [_][]const u8{
        "Validation/ImplVal.cpp",
    };

    const impl_src = impl_src: {
        const vk_impl_src = [_][]const u8{
            "VK/ImplVK.cpp",
        };

        const d3d12_impl_src = [_][]const u8{
            "D3D12/ImplD3D12.cpp",
        };

        const d3d11_impl_src = [_][]const u8{
            "D3D11/ImplD3D11.cpp",
        };

        const none_impl_src = [_][]const u8{
            "NONE/ImplNONE.cpp",
        };

        break :impl_src switch (target_backend) {
            .vulkan => vk_impl_src,
            .d3d12 => d3d12_impl_src,
            .d3d11 => d3d11_impl_src,
            .none => none_impl_src,
        };
    };

    const src =
        shared_src ++
        creation_src ++
        impl_src ++
        if (enable_validation) validation_src else .{};

    const cxxflags = [_][]const u8{
        "-std=c++17",
        "-msse4.1",
        "-Wextra",
        "-Wno-missing-field-initializers",
    };

    nri_lib.addCSourceFiles(.{
        .root = nri_dep.path("Source"),
        .files = &src,
        .flags = &cxxflags,
    });
    nri_lib.linkLibC();
    nri_lib.linkLibCpp();

    nri_lib.installHeadersDirectory(nri_dep.path("Include"), "", .{});
    b.installArtifact(nri_lib);
}
