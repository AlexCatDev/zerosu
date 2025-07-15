const c = @import("../CImports.zig").c;
const zm = @import("zm");
var _x: i32 = 0;
var _y: i32 = 0;
var _width: i32 = 0;
var _height: i32 = 0;
pub const Viewport = struct {
    pub fn SetViewport(x: i32, y: i32, width: i32, height: i32) void {
        c.glViewport(x, y, width, height);
        c.glScissor(x, y, width, height);

        _x = x;
        _y = y;
        _width = width;
        _height = height;
    }

    pub fn SetViewportSize(width: i32, height: i32) void {
        SetViewport(_x, _y, width, height);

        _width = width;
        _height = height;
    }

    pub fn GetSize() zm.vec.Vec(2, i32) {
        return .{ _width, _height };
    }

    pub fn GetSizeF() zm.Vec2f {
        return .{ @as(f32, @floatFromInt(_width)), @as(f32, @floatFromInt(_height)) };
    }
};
