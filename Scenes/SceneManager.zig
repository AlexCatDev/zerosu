const std = @import("std");
const Graphics = @import("../Easy2D/Graphics.zig").Graphics;

const c = @import("../CImports.zig").c;

pub const OnEnterFn = *const fn () void;
pub const OnExitFn = *const fn () void;
pub const OnUpdateFn = *const fn (delta: f32) void;
pub const OnDrawFn = *const fn (g: *Graphics) void;
pub const OnEventFn = *const fn (g: *const c.SDL_Event) void;

pub const SceneFnTable = struct {
    OnEnter: OnEnterFn,
    OnExit: OnExitFn,
    OnUpdate: OnUpdateFn,
    OnDraw: OnDrawFn,
    OnEvent: OnEventFn,
};

pub const SceneInfo = struct {
    BasePtr: *anyopaque,
    ID: u64,
    FnTable: SceneFnTable,

    pub fn GetTypeID(comptime T: type) u64 {
        const name = @typeName(T);
        const seed: u64 = 0x72745678_abddef69;
        return std.hash.Wyhash.hash(seed, name);
    }
};

//singleton instance
var _sceneManager: ?SceneManager = null;
pub const SceneManager = struct {
    m_SceneList: std.ArrayList(SceneInfo) = .init(std.heap.c_allocator),
    m_ActiveScene: ?SceneInfo = null,

    //Singleton
    pub fn GetInstance() *SceneManager {
        if (_sceneManager == null) {
            _sceneManager = SceneManager{};
            std.debug.print("Created SceneManager!\n", .{});
        }

        return &(_sceneManager.?);
    }

    pub fn AddScene(self: *SceneManager, comptime T: type, sceneInstance: *T, sceneFnTable: SceneFnTable) void {
        const sceneInfo = SceneInfo{ .BasePtr = @ptrCast(sceneInstance), .ID = SceneInfo.GetTypeID(T), .FnTable = sceneFnTable };

        _ = self.m_SceneList.append(sceneInfo) catch {};

        if (self.m_ActiveScene == null) {
            self.m_ActiveScene = sceneInfo;
            sceneInfo.FnTable.OnEnter();
        }
    }

    pub fn SetScene(comptime T: type) !void {
        const self = GetInstance();

        for (self.m_SceneList.items) |scene| {
            if (scene.ID == SceneInfo.GetTypeID(T)) {
                //First notify our current screen we're leaving
                if (self.m_ActiveScene) |active_scene| {
                    active_scene.FnTable.OnExit();
                }

                scene.FnTable.OnEnter();
                self.m_ActiveScene = scene;
            }
        }
    }

    pub fn OnDraw(g: *Graphics) void {
        const self = GetInstance();

        if (self.m_ActiveScene) |active_scene| {
            active_scene.FnTable.OnDraw(g);
        }
    }

    pub fn OnUpdate(delta: f32) void {
        const self = GetInstance();

        if (self.m_ActiveScene) |active_scene| {
            active_scene.FnTable.OnUpdate(delta);
        }
    }

    pub fn OnEvent(event: *const c.SDL_Event) void {
        const self = GetInstance();

        if (self.m_ActiveScene) |active_scene| {
            active_scene.FnTable.OnEvent(event);
        }
    }
};
