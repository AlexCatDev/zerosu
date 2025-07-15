const std = @import("std");
const DrawableManager = @import("../../Drawables/DrawableManager.zig").DrawableManager;
const DrawableData = @import("../../Drawables/DrawableManager.zig").DrawableData;

const c = @import("../../CImports.zig").c;

const Texture = @import("../../Easy2D/Texture.zig").Texture;

const PlayableBeatmap = @import("../PlayableBeatmap.zig").PlayableBeatmap;
const HitObject = @import("../OsuParser.zig").HitObject;
const Graphics = @import("../../Easy2D/Graphics.zig").Graphics;

const zm = @import("zm");
const Input = @import("../../Input.zig").Input;

const PlayScene = @import("../../Scenes/PlayScene.zig").PlayScene;
const Skin = @import("../Skin.zig").Skin;
const MathUtils = @import("../../MathUtils.zig").MathUtils;

pub const DrawableHitCircle = struct {
    Layer: i32 = 0,
    IsDead: bool = false,
    Beatmap: *PlayableBeatmap,
    HitCircle: HitObject,
    Alpha: f32 = 0.0,
    pub fn GetData(self: *DrawableHitCircle) DrawableData {
        return .{
            .BaseObjectPtr = @constCast(@ptrCast(self)),
            .BaseObjectTypeID = DrawableData.GetTypeID(DrawableHitCircle),
            .OnDrawFn = Draw,
            .OnUpdateFn = Update,
            .OnEventFn = OnEvent,
            .OnAddFn = OnAdd,
            .Layer = &self.Layer,
            .IsDead = &self.IsDead,
        };
    }

    fn OnAdd(selfP: *anyopaque, _: *DrawableManager) void {
        const self: *@This() = @ptrCast(@alignCast(selfP));

        _ = self;
    }

    fn OnEvent(selfP: *anyopaque, event: *const c.SDL_Event) bool {
        const self: *@This() = @ptrCast(@alignCast(selfP));

        _ = self;
        _ = event;
        return false;
    }

    pub fn Update(selfP: *anyopaque, delta: f32) void {
        const self: *@This() = @ptrCast(@alignCast(selfP));
        _ = self;
        _ = delta;
    }

    pub fn DrawHitCircle(g: *Graphics, beatmap: *const PlayableBeatmap, hit_object: *const HitObject, stacking_offset: zm.Vec2f, song_pos: f32) void {
        const TEXT_RECT: zm.Vec4f = .{ 0.0, 0.0, 1.0, 1.0 };
        const EXPLODE: f32 = 1.5;

        const FADE_OUT: f32 = 241.0;

        //const song_pos: f32 = @floatCast((beatmap.Song.GetPlaybackPositionInSeconds() * 1000.0));
        const fade_in_start: f32 = @floatFromInt(hit_object.StartTime - beatmap.Preempt);
        const fade_in_duration: f32 = @floatFromInt(beatmap.FadeIn);
        const fade_in_end: f32 = fade_in_start + fade_in_duration;
        const preempt_end: f32 = @floatFromInt(hit_object.StartTime);

        var approach_scale = MathUtils.Map(song_pos, fade_in_start, preempt_end, 4.0, 1.0);

        approach_scale = std.math.clamp(approach_scale, 1.0, 4.0);

        const hit_time = preempt_end;
        const explode_start = hit_time;
        const explode_end = hit_time + FADE_OUT;

        var explode_scale = MathUtils.Map(song_pos, explode_start, explode_end, 1.0, EXPLODE);
        explode_scale = std.math.clamp(explode_scale, 1.0, EXPLODE);
        const fade_out_scale = MathUtils.Map(explode_scale, 1.0, EXPLODE, 1.0, 0.0);

        if (fade_out_scale == 0.0)
            return;

        var alpha = MathUtils.Map(song_pos, fade_in_start, fade_in_end, 0.0, 1.0);

        alpha = std.math.clamp(alpha * fade_out_scale, 0.0, 1.0);

        const draw_pos = PlayableBeatmap.MapToPlayfield(hit_object.X, hit_object.Y);
        const draw_size = beatmap.GetWorldCircleSize();
        const draw_color = zm.Vec4f{ @sin(song_pos * 0.002), 0.5, 1.0, alpha };
        const draw_color_white = zm.Vec4f{ 1.0, 1.0, 1.0, alpha };

        const skin = PlayScene.GetSkin();

        g.DrawRectangleCentered(draw_pos + stacking_offset, draw_size * zm.Vec2f{ explode_scale, explode_scale }, draw_color, &skin.HitCircle.BackingTexture, TEXT_RECT);
        g.DrawRectangleCentered(draw_pos + stacking_offset, draw_size * zm.Vec2f{ explode_scale, explode_scale }, draw_color_white, &skin.HitCircleOverlay.BackingTexture, TEXT_RECT);

        if (approach_scale > 1.0) {
            g.DrawRectangleCentered(draw_pos + stacking_offset, draw_size * zm.Vec2f{ approach_scale, approach_scale }, draw_color, &skin.ApproachCircle.BackingTexture, TEXT_RECT);
        }
    }

    pub fn Draw(selfP: *anyopaque, g: *Graphics) void {
        const self: *@This() = @ptrCast(@alignCast(selfP));
        const TEXT_RECT: zm.Vec4f = .{ 0.0, 0.0, 1.0, 1.0 };
        const EXPLODE: f32 = 1.5;

        const FADE_OUT: f32 = 241.0;

        const song_pos: f32 = @floatCast((self.Beatmap.Song.GetPlaybackPositionInSeconds() * 1000.0));

        const fade_in_start: f32 = @floatFromInt(self.HitCircle.StartTime - self.Beatmap.Preempt);
        const fade_in_duration: f32 = @floatFromInt(self.Beatmap.FadeIn);
        const fade_in_end: f32 = fade_in_start + fade_in_duration;
        const preempt_end: f32 = @floatFromInt(self.HitCircle.StartTime);

        var approach_scale = MathUtils.Map(song_pos, fade_in_start, preempt_end, 4.0, 1.0);

        approach_scale = std.math.clamp(approach_scale, 1.0, 4.0);

        const hit_time = preempt_end;
        const explode_start = hit_time;
        const explode_end = hit_time + FADE_OUT;

        var explode_scale = MathUtils.Map(song_pos, explode_start, explode_end, 1.0, EXPLODE);
        explode_scale = std.math.clamp(explode_scale, 1.0, EXPLODE);
        const fade_out_scale = MathUtils.Map(explode_scale, 1.0, EXPLODE, 1.0, 0.0);

        if (fade_out_scale == 0.0)
            self.IsDead = true;

        var alpha = MathUtils.Map(song_pos, fade_in_start, fade_in_end, 0.0, 1.0);

        alpha = std.math.clamp(alpha * fade_out_scale, 0.0, 1.0);

        const stacking_vector = zm.Vec2f{ self.Beatmap.CircleSizeOsuPixels / 5.0, self.Beatmap.CircleSizeOsuPixels / 5.0 };
        const stacking_count = zm.Vec2f{ @floatFromInt(self.HitCircle.StackCount), @floatFromInt(self.HitCircle.StackCount) };

        const stacking_offset = stacking_vector * stacking_count;

        const draw_pos = PlayableBeatmap.MapToPlayfield(self.HitCircle.X, self.HitCircle.Y) + stacking_offset;
        const draw_size = self.Beatmap.GetWorldCircleSize();
        const draw_color = zm.Vec4f{ @sin(song_pos * 0.002), 0.5, 1.0, alpha };
        const draw_color_white = zm.Vec4f{ 1.0, 1.0, 1.0, alpha };

        const skin = PlayScene.GetSkin();

        g.DrawRectangleCentered(draw_pos, draw_size * zm.Vec2f{ explode_scale, explode_scale }, draw_color, &skin.HitCircle.BackingTexture, TEXT_RECT);
        g.DrawRectangleCentered(draw_pos, draw_size * zm.Vec2f{ explode_scale, explode_scale }, draw_color_white, &skin.HitCircleOverlay.BackingTexture, TEXT_RECT);

        if (approach_scale > 1.0) {
            g.DrawRectangleCentered(draw_pos, draw_size * zm.Vec2f{ approach_scale, approach_scale }, draw_color, &skin.ApproachCircle.BackingTexture, TEXT_RECT);
        }
    }
};
