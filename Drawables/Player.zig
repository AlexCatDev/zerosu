const std = @import("std");
const DrawableManager = @import("DrawableManager.zig").DrawableManager;
const DrawableData = @import("DrawableManager.zig").DrawableData;

const c = @import("../CImports.zig").c;

const Texture = @import("../Easy2D/Texture.zig").Texture;

const Graphics = @import("../Easy2D/Graphics.zig").Graphics;

const zm = @import("zm");
const Input = @import("../Input.zig").Input;

pub const Player = struct {
    Position: zm.Vec2f = .{ 0.0, 0.0 },
    Layer: i32 = 0,
    Texture: Texture,
    IsDead: bool = false,
    Velocity: zm.Vec2f = .{ 0.0, 0.0 },
    manager: ?*DrawableManager = null,

    pub fn GetData(self: *Player) DrawableData {
        return .{
            .BaseObjectPtr = @constCast(@ptrCast(self)),
            .BaseObjectTypeID = DrawableData.GetTypeID(Player),
            .OnDrawFn = Draw,
            .OnUpdateFn = Update,
            .OnEventFn = OnEvent,
            .OnAddFn = OnAdd,
            .Layer = &self.Layer,
            .IsDead = &self.IsDead,
        };
    }

    fn OnAdd(selfP: *anyopaque, _: *DrawableManager) void {
        const self: *Player = @ptrCast(@alignCast(selfP));

        _ = self;
    }

    fn OnEvent(selfP: *anyopaque, event: *const c.SDL_Event) bool {
        const self: *Player = @ptrCast(@alignCast(selfP));

        const is_press = event.type == c.SDL_KEYDOWN;
        const is_release = event.type == c.SDL_KEYUP;
        if (!is_press and !is_release) return false;

        const scancode = event.key.keysym.scancode;
        _ = scancode;

        _ = self;
        //switch (scancode) {
        //    c.SDL_SCANCODE_D => {
        //        self.Velocity[0] = if (is_press) 300.0 else 0;
        //    },
        //    c.SDL_SCANCODE_W => {
        //        self.Velocity[1] = if (is_press) -300.0 else 0;
        //    },
        //    c.SDL_SCANCODE_A => {
        //        self.Velocity[0] = if (is_press) -300.0 else 0;
        //    },
        //    c.SDL_SCANCODE_S => {
        //        self.Velocity[1] = if (is_press) 300.0 else 0;
        //    },
        //    else => {
        //        self.Velocity = .{ 0.0, 0.0 };
        //    },
        //}

        //if (event.type == c.SDL_KEYDOWN) {
        //    if (event.key.keysym.scancode == c.SDL_SCANCODE_D) {
        //        self.Velocity[0] = 300.0;
        //    } else if (event.key.keysym.scancode == c.SDL_SCANCODE_W) {
        //        self.Velocity[1] = -300.0;
        //    }
        //} else if (event.type == c.SDL_KEYUP) {
        //    if (event.key.keysym.scancode == c.SDL_SCANCODE_D) {
        //        self.Velocity[0] = 0;
        //    } else if (event.key.keysym.scancode == c.SDL_SCANCODE_W) {
        //        self.Velocity[1] = 0;
        //    }
        //}

        //_ = self;
        //_ = event;
        //std.debug.print("SDL EVENT IN PLAYER!", .{});
        return false;
    }

    pub fn Update(selfP: *anyopaque, delta: f32) void {
        var self: *Player = @ptrCast(@alignCast(selfP));

        if (Input.IsKeyDown(c.SDL_SCANCODE_W)) {
            self.Velocity[1] = -300;
        } else if (Input.IsKeyDown(c.SDL_SCANCODE_S)) {
            self.Velocity[1] = 300;
        } else {
            self.Velocity[1] = 0;
        }

        if (Input.IsKeyDown(c.SDL_SCANCODE_A)) {
            self.Velocity[0] = -300;
        } else if (Input.IsKeyDown(c.SDL_SCANCODE_D)) {
            self.Velocity[0] = 300;
        } else {
            self.Velocity[0] = 0;
        }

        self.Velocity[1] = std.math.clamp(self.Velocity[1], -500, 500);

        self.Position[0] += self.Velocity[0] * delta;
        self.Position[1] += self.Velocity[1] * delta;
    }

    pub fn Draw(selfP: *anyopaque, g: *Graphics) void {
        const self: *Player = @ptrCast(@alignCast(selfP));
        g.DrawRectangle(.{ self.Position[0], self.Position[1] }, .{ 64.0, 64.0 }, .{ 0.0, 0.5, 0.5, 1.0 }, &self.Texture, .{ 0.0, 0.0, 1.0, 1.0 });
    }
};
