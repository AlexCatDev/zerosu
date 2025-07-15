const std = @import("std");
const DrawableManager = @import("../../Drawables/DrawableManager.zig").DrawableManager;
const DrawableData = @import("../../Drawables/DrawableManager.zig").DrawableData;

const c = @import("../../CImports.zig").c;

const Texture = @import("../../Easy2D/Texture.zig").Texture;

const PlayableBeatmap = @import("../PlayableBeatmap.zig").PlayableBeatmap;

const Graphics = @import("../../Easy2D/Graphics.zig").Graphics;

const zm = @import("zm");
const Input = @import("../../Input.zig").Input;

pub const _NAME = struct {
    Layer: i32 = 0,
    IsDead: bool = false,
    Beatmap: *const PlayableBeatmap,
    StackingOffset: zm.Vec2f,

    pub fn GetData(self: *@This()) DrawableData {
        return .{
            .BaseObjectPtr = @constCast(@ptrCast(self)),
            .BaseObjectTypeID = DrawableData.GetTypeID(@This()),
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

    pub fn Draw(selfP: *anyopaque, g: *Graphics) void {
        const self: *@This() = @ptrCast(@alignCast(selfP));
        _ = self;
        _ = g;
    }
};
