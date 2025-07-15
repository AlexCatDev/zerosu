const c = @import("CImports.zig").c;
const std = @import("std");

pub const Input = struct {
    pub fn IsKeyDown(key: c_int) bool {
        var numKeys: c_int = 0;
        const keys = c.SDL_GetKeyboardState(&numKeys);

        //std.debug.print("States[{d}]: \n", .{numKeys});
        //for (0..@intCast(numKeys)) |i| {
        //    if (keys[i] > 0)
        //        std.debug.print(" [{d}:{d}] ", .{ i, keys[i] });
        //}

        if (keys[@intCast(key)] == 1)
            return true;

        return false;
    }

    pub fn GetMouseState() struct { X: f32, Y: f32, IsLeftDown: bool, IsRightDown: bool, IsMiddleDown: bool } {
        const x: c_int = 0;
        const y: c_int = 0;
        const state = c.SDL_GetMouseState(&x, &y);

        // Check if left button is held
        const left_down = (state & c.SDL_BUTTON(c.SDL_BUTTON_LEFT)) != 0;

        // Check if right button is held
        const right_down = (state & c.SDL_BUTTON(c.SDL_BUTTON_RIGHT)) != 0;

        // Check if middle button is held
        const middle_down = (state & c.SDL_BUTTON(c.SDL_BUTTON_MIDDLE)) != 0;

        return .{
            .X = @floatFromInt(x),
            .Y = @floatFromInt(y),
            .IsLeftDown = left_down,
            .IsRightDown = right_down,
            .IsMiddleDown = middle_down,
        };
    }
};
