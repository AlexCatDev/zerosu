const std = @import("std");

const Texture = @import("../Easy2D/Texture.zig").Texture;

pub const OsuTexture = struct {
    BackingTexture: Texture,
    Is2X: bool,
};

pub const SUPPORTED_EXTENSIONS = [_][]const u8{
    "@2x.png",
    "@2x.jpg",
    "@2x.jpeg",
    ".png",
    ".jpg",
    ".jpeg",
};

var _dotTexture: ?Texture = null;
const _dotTextureData = @embedFile("../textures/circle.png");
pub const Skin = struct {
    ApproachCircle: OsuTexture,
    HitCircle: OsuTexture,
    HitCircleOverlay: OsuTexture,
    SliderBall: OsuTexture,
    DotTexture: *const Texture,

    pub fn LoadFromFolder(folder_path: []const u8) Skin {
        const approach_circle = loadOsuTexture(folder_path, "approachcircle") catch unreachable;
        const hit_circle = loadOsuTexture(folder_path, "hitcircle") catch unreachable;
        const hit_circle_overlay = loadOsuTexture(folder_path, "hitcircleoverlay") catch unreachable;
        const sliderball = loadOsuTexture(folder_path, "sliderb0") catch unreachable;

        if (_dotTexture == null) {
            _dotTexture = Texture.Init(_dotTextureData) catch unreachable;
        }

        return .{
            .ApproachCircle = approach_circle,
            .HitCircle = hit_circle,
            .HitCircleOverlay = hit_circle_overlay,
            .DotTexture = &_dotTexture.?,
            .SliderBall = sliderball,
        };
    }

    fn loadOsuTexture(folder_path: []const u8, name_no_extension: []const u8) !OsuTexture {
        //First loop through all files looking for each extension with the 2X tag, after that do the same but without
        //TODO: if texture can't be found load some kind of error texture.

        for (SUPPORTED_EXTENSIONS) |extension| {
            const file_name = std.fmt.allocPrint(std.heap.c_allocator, "{s}{s}", .{ name_no_extension, extension }) catch unreachable;
            defer std.heap.c_allocator.free(file_name);
            const file_path = std.fmt.allocPrint(std.heap.c_allocator, "{s}/{s}{s}", .{ folder_path, name_no_extension, extension }) catch unreachable;
            defer std.heap.c_allocator.free(file_path);

            var working_dir: std.fs.Dir = undefined;

            if (folder_path[0] == '.') {
                working_dir = std.fs.cwd().openDir(folder_path, .{}) catch |dirErr| {
                    std.debug.print("Error Opening cwd: {} at@{s}\n", .{ dirErr, folder_path });

                    continue;
                };
            } else {
                working_dir = std.fs.openDirAbsolute(folder_path, .{}) catch |dirErr| {
                    std.debug.print("Error Opening absoluteDir: {} at@{s}\n", .{ dirErr, folder_path });

                    continue;
                };
            }

            const file = working_dir.openFile(file_name, .{}) catch |fileErr| {
                std.debug.print("{} {s} -> {s}\n", .{ fileErr, folder_path, file_name });

                continue;
            };

            //const file = std.fs.openFileAbsolute(file_path, .{}) catch continue;
            const fileData = try file.readToEndAlloc(std.heap.c_allocator, 50000000);
            defer std.heap.c_allocator.free(fileData);

            const is_2x = extension[0] == '@';

            return .{
                .BackingTexture = try Texture.Init(fileData),
                .Is2X = is_2x,
            };
        }

        return error.CantFindTexture;
    }
};
