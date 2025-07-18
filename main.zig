const std = @import("std");
const c = @import("CImports.zig").c;

const Texture = @import("Easy2D/Texture.zig").Texture;

const Graphics = @import("Easy2D/Graphics.zig").Graphics;

const DrawableManager = @import("Drawables/DrawableManager.zig").DrawableManager;
const DrawableData = @import("Drawables/DrawableManager.zig").DrawableData;
const Player = @import("Drawables/Player.zig").Player;

const SceneManager = @import("Scenes/SceneManager.zig").SceneManager;
const MenuScene = @import("Scenes/MenuScene.zig").MenuScene;
const PlayScene = @import("Scenes/PlayScene.zig").PlayScene;
const TestScene = @import("Scenes/TestScene.zig").TestScene;

const Viewport = @import("Easy2D/Viewport.zig").Viewport;

const zm = @import("zm");

const Sound = @import("Sound.zig").Sound;

const Beatmap = @import("Osu/OsuParser.zig").Beatmap;
const PlayableBeatmap = @import("Osu/PlayableBeatmap.zig").PlayableBeatmap;

const Replay = @import("Osu/ReplayParser.zig").Replay;

pub fn main() !void {
    std.debug.print("\nHello zig!\n\n", .{});

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.debug.print("SDL_Init Error: {s}\n", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_Quit();

    // Request OpenGL ES 2.0 context
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);

    var width: i32 = 1280;
    var height: i32 = 720;

    const window = c.SDL_CreateWindow("game", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, width, height, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);

    if (window == null) {
        std.debug.print("SDL_CreateWindow Error: {s}\n", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_DestroyWindow(window);

    Sound.InitBass(window);

    const gl_context = c.SDL_GL_CreateContext(window);
    if (gl_context == null) {
        std.debug.print("SDL_GL_CreateContext Error: {s}\n", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_GL_DeleteContext(gl_context);

    _ = c.SDL_GL_SetSwapInterval(0);

    c.glDisable(c.GL_DEPTH_TEST);
    c.glEnable(c.GL_TEXTURE);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    //c.glClearColor(0.39, 0.58, 0.93, 1.0);
    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    var projectionMatrix = zm.Mat4f.orthographic(0.0, @floatFromInt(width), @floatFromInt(height), 0.0, -1.0, 1.0);

    const circleTextureData = @embedFile("textures/circle.png");

    const circleTexture = try Texture.Init(circleTextureData);

    var g = try Graphics.Init();

    var event: c.SDL_Event = undefined;
    var running = true;

    var mousePos: zm.Vec2f = .{ 0.0, 0.0 };

    var prev = try std.time.Instant.now();
    var total_time: f32 = 0.0;
    var fps: i32 = 0;
    var fpsTimer: f64 = 0.0;

    //   const gameObjMan = GameObjectManager.Init();
    //
    //   var player = Player{ .Position = .{ 200.0, 200.0 } };
    //
    //   const objData = player.GetObjData();
    //
    //   gameObjMan.AddObject(objData);

    var player = Player{ .Position = .{ 200.0, 200.0 }, .Layer = 0, .Texture = circleTexture };
    //player.Draw(@ptrCast(player), g);
    //Player.Draw(@ptrCast(&player), &g);

    const playerData = player.GetData();

    var gameObjMan = DrawableManager.Init();

    try gameObjMan.Add(playerData);

    std.debug.print("PlayerID: {d}\n", .{playerData.BaseObjectTypeID});
    PlayableBeatmap.UpdatePlayfield(@floatFromInt(width), @floatFromInt(height));
    Viewport.SetViewport(0, 0, width, height);
    const x = struct {
        pub fn Callback(_: *Player) bool {
            std.debug.print("Got object:\n", .{});
            return false;
        }
    };

    gameObjMan.GetAllOfType(Player, x.Callback);

    SceneManager.GetInstance().AddScene(PlayScene, PlayScene.GetInstance(), PlayScene.GetFnTable());
    SceneManager.GetInstance().AddScene(MenuScene, MenuScene.GetInstance(), MenuScene.GetFnTable());
    SceneManager.GetInstance().AddScene(TestScene, TestScene.GetInstance(), TestScene.GetFnTable());
    while (running) {
        const now = try std.time.Instant.now();
        const delta_ns = now.since(prev); //nanoseconds
        prev = now;

        const d_delta = @as(f64, @floatFromInt(delta_ns)) / 1_000_000_000.0;
        const delta: f32 = @floatCast(d_delta);
        total_time += delta;

        fps += 1;
        fpsTimer += d_delta;

        if (fpsTimer >= 1.0) {
            std.debug.print("FPS: {d}\n", .{fps});
            fps = 0;
            fpsTimer -= 1.0;
        }

        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }

            if (event.type == c.SDL_MOUSEMOTION) {
                mousePos = .{ @floatFromInt(event.motion.x), @floatFromInt(event.motion.y) };

                //std.debug.print("Mouse X: {d} Y: {d}\n", .{ mouseX, mouseY });
            }

            if (event.type == c.SDL_WINDOWEVENT) {
                if (event.window.event == c.SDL_WINDOWEVENT_SIZE_CHANGED) {
                    width = event.window.data1;
                    height = event.window.data2;
                    //std.debug.print("Resized: {d},{d}\n", .{ width, height });
                    PlayableBeatmap.UpdatePlayfield(@floatFromInt(width), @floatFromInt(height));
                    projectionMatrix = zm.Mat4f.orthographic(0.0, @floatFromInt(width), @floatFromInt(height), 0.0, -1.0, 1.0);
                    Viewport.SetViewport(0, 0, width, height);
                }
            }
            const k = &event;

            _ = gameObjMan.OnEvent(k);
            SceneManager.OnEvent(k);
        }

        //clear screen to cornflower blue
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        g.Time = total_time;
        g.ProjectionMatrix = projectionMatrix;

        SceneManager.OnUpdate(delta);
        SceneManager.OnDraw(&g);

        gameObjMan.Update(delta);
        gameObjMan.Draw(&g);

        g.DrawRectangleCentered(mousePos, .{ 16.0, 16.0 }, .{ 1.0, 0.0, 0.0, 1.0 }, &circleTexture, .{ 0.0, 0.0, 1.0, 1.0 });

        g.EndDraw();

        c.SDL_GL_SwapWindow(window);
        //return;
        //std.Thread.sleep(1_000_000);
    }
}
