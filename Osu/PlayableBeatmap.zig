//Make playable beatmap struct

//Takes folder path, map file name
//First parses the osu map, then loads audio, Then builds a list of drawable hitobjects, Which goes in a arraylist of drawabledata?

//DrawableHitObjectData
//
//Drawable Hitobjects should have a pointer to playablebeatmap where it can get that beatmap's difficulty settings, and the audio time, etc

const std = @import("std");
const Sound = @import("../Sound.zig").Sound;
const Beatmap = @import("OsuParser.zig").Beatmap;
const zm = @import("zm");
const MathUtils = @import("../MathUtils.zig").MathUtils;

var _playfield = zm.Vec4f{ 0.0, 0.0, 0.0, 0.0 };
var _osu_to_world_scale: f32 = 0.0;
pub const PlayableBeatmap = struct {
    Beatmap: Beatmap,
    Song: Sound,
    Preempt: i32 = 0,
    FadeIn: i32 = 0,
    CircleSizeOsuPixels: f32 = 0,
    pub fn Load(allocator: std.mem.Allocator, folderPath_1: []const u8, osuMapName: []const u8) !PlayableBeatmap {
        //Load beatmap file

        var real_folder_path = folderPath_1;

        var file_path_buf: [1024]u8 = undefined;
        if (tryGetAbsolutePath(&file_path_buf, folderPath_1)) |real_path| {
            real_folder_path = real_path;
        }

        const osu_file_path = std.fmt.allocPrint(allocator, "{s}/{s}.osu", .{ real_folder_path, osuMapName }) catch unreachable;
        defer allocator.free(osu_file_path);

        const map_file = try std.fs.openFileAbsolute(osu_file_path, .{});
        defer map_file.close();
        const beatmap_text = std.fs.File.readToEndAlloc(map_file, allocator, 500_000_00) catch unreachable;
        defer allocator.free(beatmap_text);

        var beatmap = Beatmap.FromString(allocator, beatmap_text);
        beatmap.StackObjectsPass();
        const song_file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ real_folder_path, beatmap.General.AudioFilename }) catch unreachable;
        defer allocator.free(song_file_path);

        const song = Sound.FromFile(song_file_path);

        var final_bm: PlayableBeatmap = .{
            .Beatmap = beatmap,
            .Song = song,
        };

        final_bm.ApplyMods();

        return final_bm;
    }

    ///If _path_ starts with a "./" it's asumed to be a relative-to-exe path and will resolve the path and return a view into buffer, otherwise returns null if not detected or there was an error
    fn tryGetAbsolutePath(buffer: []u8, path: []const u8) ?[]const u8 {
        if (path.len < 2)
            return null;

        if (path[0] == '.' and path[1] == '/') {
            //copy the exe path to the start of the buffer

            const exe_path = std.fs.selfExeDirPath(buffer[0..]) catch return null;
            //now copy the input path into the buffer, at the offset of where the exepath starts, and only copy after the "."

            if (exe_path.len + (path.len - 1) > buffer.len)
                return null;

            std.mem.copyForwards(u8, buffer[exe_path.len..], path[1..]);

            //slice to correct length
            return buffer[0 .. (path.len - 1) + exe_path.len];
        }

        return null;
    }

    pub fn ApplyMods(self: *PlayableBeatmap) void {
        const ar = self.Beatmap.Difficulty.ApproachRate;
        const cs = self.Beatmap.Difficulty.CircleSize;

        const preempt = Beatmap.MapDifficultyRange(ar, 1800.0, 1200.0, 450.0);

        self.Preempt = @as(i32, @intFromFloat(preempt));

        self.FadeIn = @as(i32, @intFromFloat(400.0 * @min(1.0, preempt / 450.0)));

        self.CircleSizeOsuPixels = 54.4 - 4.48 * cs;
    }

    pub fn GetStackVector(self: *const PlayableBeatmap) zm.Vec2f {
        const stack_amount = (self.CircleSizeOsuPixels * _osu_to_world_scale) / 10.0;
        return .{ stack_amount, stack_amount };
    }

    pub fn OsuToWorldScale() f32 {
        return _osu_to_world_scale;
    }

    pub fn GetWorldCircleSize(self: *const PlayableBeatmap) zm.Vec2f {
        return .{ self.CircleSizeOsuPixels * _osu_to_world_scale * 2.0, self.CircleSizeOsuPixels * _osu_to_world_scale * 2.0 };
    }

    pub fn MapToPlayfield(x: i32, y: i32) zm.Vec2f {
        const new_x = MathUtils.Map(@as(f32, @floatFromInt(x)), 0.0, 512.0, _playfield[0], _playfield[0] + _playfield[2]);
        const new_y = MathUtils.Map(@as(f32, @floatFromInt(y)), 0.0, 384.0, _playfield[1], _playfield[1] + _playfield[3]);
        return .{ new_x, new_y };
    }

    pub fn MapToPlayfield2(x: f32, y: f32) zm.Vec2f {
        const new_x = MathUtils.Map(x, 0.0, 512.0, _playfield[0], _playfield[0] + _playfield[2]);
        const new_y = MathUtils.Map(y, 0.0, 384.0, _playfield[1], _playfield[1] + _playfield[3]);
        return .{ new_x, new_y };
    }

    pub fn MapSliderToPlayfield(sliderBounds: zm.Vec4f) zm.Vec4f {
        var out = zm.Vec4f{ 0.0, 0.0, 0.0, 0.0 };

        out[0] = MathUtils.Map(sliderBounds[0], 0, 512, _playfield[0], _playfield[0] + _playfield[2]);
        out[1] = MathUtils.Map(sliderBounds[1], 0, 384, _playfield[1], _playfield[1] + _playfield[3]);

        out[2] = MathUtils.Map(sliderBounds[2], 0, 512, _playfield[0], _playfield[0] + _playfield[2]);
        out[3] = MathUtils.Map(sliderBounds[3], 0, 384, _playfield[1], _playfield[1] + _playfield[3]);

        return out;
    }

    pub fn UpdatePlayfield(viewport_width: f32, viewport_height: f32) void {
        const ASPECTRATIO = 4.0 / 3.0;

        var playfieldHeight = viewport_height * 0.8;
        var playfieldWidth = playfieldHeight * ASPECTRATIO;

        if (playfieldWidth > viewport_width) {
            playfieldWidth = viewport_width;
            playfieldHeight = playfieldWidth / ASPECTRATIO;
        }

        _playfield[2] = playfieldWidth;
        _playfield[3] = playfieldHeight;

        _playfield[0] = viewport_width * 0.5 - playfieldWidth * 0.5;
        _playfield[1] = viewport_height * 0.5 - playfieldHeight * 0.5;

        const playfieldYOffset = playfieldHeight * 0.020;

        _playfield[1] += playfieldYOffset;

        _osu_to_world_scale = playfieldHeight / 384.0;
    }
};
