const std = @import("std");

const SceneFnTable = @import("SceneManager.zig").SceneFnTable;
const Graphics = @import("../Easy2D/Graphics.zig").Graphics;
const c = @import("../CImports.zig").c;

const PlayableBeatmap = @import("../Osu/PlayableBeatmap.zig").PlayableBeatmap;
const HitObject = @import("../Osu/OsuParser.zig").HitObject;

const DrawableHitCircle = @import("../Osu/Drawables/DrawableHitCircle.zig").DrawableHitCircle;
const DrawableHitSlider = @import("../Osu/Drawables/DrawableHitSlider.zig").DrawableHitSlider;
const DrawableManager = @import("../Drawables/DrawableManager.zig").DrawableManager;

const Skin = @import("../Osu/Skin.zig").Skin;

var _playScene: ?PlayScene = null;

var _playingBeatmap: ?PlayableBeatmap = null;
var _objectIndex: usize = 0;
var _hitObjMan = DrawableManager.Init();

var _drawableArenaAllocator = std.heap.ArenaAllocator.init(std.heap.c_allocator);
var _drawableAllocator = _drawableArenaAllocator.allocator();

var _skin: ?Skin = null;

pub const PlayScene = struct {
    pub fn GetInstance() *PlayScene {
        if (_playScene == null) {
            _playScene = PlayScene{};
            std.debug.print("Created {s}!\n", .{@typeName(@This())});
        }

        return &(_playScene.?);
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

    pub fn GetSkin() *Skin {
        return &_skin.?;
    }

    //Doesnt really need a ptr to self since the instance is a singleton
    fn OnEnter() void {
        std.debug.print("{s}.OnEnter: Hello :D\n", .{@typeName(@This())});

        if (_playingBeatmap == null) {
            _playingBeatmap = PlayableBeatmap.Load(std.heap.c_allocator, "./maps/fukutuidol", "map") catch unreachable;
            _playingBeatmap.?.Song.Play(true);
            _objectIndex = 0;
            const k: f64 = @floatFromInt(_playingBeatmap.?.Beatmap.HitObjects.items[_objectIndex].StartTime - 1000);
            _playingBeatmap.?.Song.SetPlaybackPositionSecs(k / 1000.0);
        }

        if (_skin == null) {
            _skin = Skin.LoadFromFolder("./skins/default");
        }

        //GetInstance()...
    }

    fn OnExit() void {}

    fn OnUpdate(delta: f32) void {
        const pos = _playingBeatmap.?.Song.GetPlaybackPositionInSeconds() * 1000.0;
        const hit_objs = _playingBeatmap.?.Beatmap.HitObjects.items;

        if (_objectIndex < hit_objs.len) {
            while (pos >= @as(f64, @floatFromInt(hit_objs[_objectIndex].StartTime - _playingBeatmap.?.Preempt))) {
                const obj_to_spawn = hit_objs[_objectIndex];

                const layer: i32 = 727_727 - @as(i32, @intCast(_objectIndex));

                if (obj_to_spawn.HitCircle != null) {
                    //This boy is on the stack and is gonna get destroyed
                    //was**
                    var drawable_hs = _drawableAllocator.create(DrawableHitCircle) catch unreachable;
                    drawable_hs.Beatmap = &_playingBeatmap.?;
                    drawable_hs.IsDead = false;
                    drawable_hs.Layer = layer;
                    drawable_hs.Alpha = 0.0;
                    drawable_hs.HitCircle = obj_to_spawn;

                    const data = drawable_hs.GetData();

                    _hitObjMan.Add(data) catch {};
                } else if (obj_to_spawn.HitSlider != null) {
                    //if (obj_to_spawn.HitSlider.?.Type == .Bezier) {
                    var drawable_slider = DrawableHitSlider.New(_drawableAllocator, obj_to_spawn, &_playingBeatmap.?, .{ 0.0, 0.0 }, layer);

                    const data = drawable_slider.GetData();

                    _hitObjMan.Add(data) catch {};
                    //}
                }

                _objectIndex += 1;
                //std.debug.print("Spawned Hitobject: {d}\n", .{_objectIndex});

                if (_objectIndex >= hit_objs.len)
                    break;
            }
        }
        _hitObjMan.Update(delta);
    }

    fn OnDraw(g: *Graphics) void {
        _hitObjMan.Draw(g);
    }

    fn OnEvent(event: *const c.SDL_Event) void {
        _ = _hitObjMan.OnEvent(event);

        if (event.type == c.SDL_KEYDOWN) {
            if (event.key.keysym.scancode == c.SDL_SCANCODE_SPACE) {
                _playingBeatmap.?.Song.TogglePlay();
            }
        } else if (event.type == c.SDL_MOUSEWHEEL) {
            //std.debug.print("Wheel: {d}\n", .{event.wheel.y});
            const wheel_delta: f32 = @floatFromInt(event.wheel.y);
            const value: f32 = wheel_delta * 0.01;
            _playingBeatmap.?.Song.SetPlaybackPositionSecs(_playingBeatmap.?.Song.GetPlaybackPositionInSeconds() + value);
        }
    }
};
