const std = @import("std");

const SceneFnTable = @import("SceneManager.zig").SceneFnTable;

const Graphics = @import("../Easy2D/Graphics.zig").Graphics;
const c = @import("../CImports.zig").c;

var _menuScene: ?MenuScene = null;

pub const MenuScene = struct {
    pub fn GetInstance() *MenuScene {
        if (_menuScene == null) {
            _menuScene = MenuScene{};
            std.debug.print("Created {s}!\n", .{@typeName(@This())});
        }

        return &(_menuScene.?);
    }

    pub fn GetFnTable() SceneFnTable {
        return SceneFnTable{
            .OnEnter = OnEnter,
            .OnExit = OnExit,
            .OnDraw = OnDraw,
            .OnUpdate = OnUpdate,
            .OnEvent = OnEvent,
        };
    }

    //Doesnt really need a ptr to self since the instance is a singleton
    fn OnEnter() void {
        std.debug.print("{s}.OnEnter: Hello :D\n", .{@typeName(@This())});
        //GetInstance()...
    }

    fn OnExit() void {}

    fn OnUpdate(_: f32) void {}

    fn OnDraw(_: *Graphics) void {}

    fn OnEvent(_: *const c.SDL_Event) void {}
};
