const std = @import("std");
const DrawableManager = @import("../../Drawables/DrawableManager.zig").DrawableManager;
const DrawableData = @import("../../Drawables/DrawableManager.zig").DrawableData;

const c = @import("../../CImports.zig").c;

const Texture = @import("../../Easy2D/Texture.zig").Texture;

const PlayableBeatmap = @import("../PlayableBeatmap.zig").PlayableBeatmap;
const HitSlider = @import("../OsuParser.zig").HitSlider;
const HitObject = @import("../OsuParser.zig").HitObject;
const SliderType = @import("../OsuParser.zig").HitSliderType;

const PlayScene = @import("../../Scenes/PlayScene.zig").PlayScene;
const DrawableHitCircle = @import("DrawableHitCircle.zig").DrawableHitCircle;
const Skin = @import("../Skin.zig").Skin;

const Viewport = @import("../../Easy2D/Viewport.zig").Viewport;

const CurveApproximator = @import("../../CurveApproximator.zig").CurveApproximator;
const MathUtils = @import("../../MathUtils.zig").MathUtils;

const Shader = @import("../../Easy2D/Shader.zig").Shader;
const IndexBuffer = @import("../../Easy2D/GLBuffer.zig").GLBuffer(u16);
const VertexBuffer = @import("../../Easy2D/GLBuffer.zig").GLBuffer(SliderVertex);
const PrimitiveBatcher = @import("../../Easy2D/PrimitiveBatcher.zig").PrimitiveBatcher(SliderVertex);

const Profiler = @import("../../Profiler.zig").Profiler;

const Graphics = @import("../../Easy2D/Graphics.zig").Graphics;

const zm = @import("zm");
const Input = @import("../../Input.zig").Input;

const SliderVertex = extern struct {
    X: f32,
    Y: f32,
    Depth: f32,

    pub fn EnableVertexAttribs() void {
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 12, @ptrFromInt(0));
    }

    pub fn DisableVertexAttribs() void {
        c.glDisableVertexAttribArray(0);
    }
};

pub const Path = struct {
    Points: []const zm.Vec2f,
    Length: f32,
    Bounds: zm.Vec4f,
    Position: zm.Vec2f,
    Width: i32,
    Height: i32,
    PointRadius: f32,

    pub fn Init(points: []const zm.Vec2f, point_radius: f32) Path {
        const length = CalculateLength(points);
        var bounds = CalculateBounds(points);

        bounds[0] -= point_radius;
        bounds[1] -= point_radius;
        bounds[2] += point_radius;
        bounds[3] += point_radius;

        return .{
            .Points = points,
            .Length = length,
            .Bounds = bounds,
            .Position = .{ bounds[0], bounds[1] },
            .Width = @as(i32, @intFromFloat(bounds[2] - bounds[0])),
            .Height = @as(i32, @intFromFloat(bounds[3] - bounds[1])),
            .PointRadius = point_radius,
        };
    }

    pub fn CalculatePositionAt(self: *const Path, l: f32) zm.Vec2f {
        var length = l;
        if (length <= 0)
            return self.Points[0];

        if (length >= self.Length)
            return self.Points[self.Points.len - 1];

        for (0..self.Points.len - 1) |i| {
            const now = self.Points[i];
            const next = self.Points[i + 1];

            const dist = zm.vec.distance(now, next);

            if (length - dist <= 0) {
                const blend = length / dist;

                return zm.vec.lerp(now, next, blend);
            }

            length -= dist;
        }

        return self.Points[self.Points.len - 1];
    }

    pub fn CalculateLength(points: []const zm.Vec2f) f32 {
        var length: f32 = 0.0;
        for (0..points.len - 1) |i| {
            length += zm.vec.distance(points[i], points[i + 1]);
        }

        return length;
    }

    pub fn CalculateBounds(points: []const zm.Vec2f) zm.Vec4f {
        var xmin = std.math.floatMax(f32);
        var xmax: f32 = 0.0;
        var ymin = std.math.floatMax(f32);
        var ymax: f32 = 0.0;

        for (points) |current| {
            if (xmin > current[0])
                xmin = current[0];

            if (ymin > current[1])
                ymin = current[1];

            if (xmax < current[0])
                xmax = current[0];

            if (ymax < current[1])
                ymax = current[1];
        }

        return .{ xmin, ymin, xmax, ymax };
    }
};

const _SliderVertSrc = @embedFile("../../shaders/slider.vert");
const _SliderFragSrc = @embedFile("../../shaders/slider.frag");

var _SliderShader: ?Shader = null;
var _SliderBatcher: ?PrimitiveBatcher = null;
var _SliderVtxBuffer: ?VertexBuffer = null;
var _SliderIdxBuffer: ?IndexBuffer = null;

pub const DrawableHitSlider = struct {
    Layer: i32 = 0,
    IsDead: bool = false,
    Beatmap: *const PlayableBeatmap,
    StackingOffset: zm.Vec2f,
    HitObject: HitObject,
    Path: Path,
    SliderTexture: Texture,
    FBO: c_uint,
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

    pub fn New(allocator: std.mem.Allocator, hit_object: HitObject, beatmap: *const PlayableBeatmap, stacking_offset: zm.Vec2f, layer: i32) *DrawableHitSlider {
        var drawable_slider = allocator.create(DrawableHitSlider) catch unreachable;

        drawable_slider.IsDead = false;
        drawable_slider.Layer = layer;
        drawable_slider.StackingOffset = stacking_offset;
        drawable_slider.Beatmap = beatmap;
        drawable_slider.HitObject = hit_object;

        //todo make these global because theres no reason to recreate memory
        Profiler.Start("Slider_Parse");
        var cp_temp_buffer = std.ArrayList(zm.Vec2f).init(allocator);
        defer cp_temp_buffer.deinit();
        var full_path_buffer = std.ArrayList(zm.Vec2f).init(allocator);

        //Add the start todo just do this in the parser lol.
        cp_temp_buffer.append(zm.Vec2f{ @floatFromInt(hit_object.X), @floatFromInt(hit_object.Y) }) catch unreachable;

        const slider_points = drawable_slider.HitObject.HitSlider.?.CurvePoints.items;

        const slider_type: SliderType = hit_object.HitSlider.?.Type;

        for (slider_points, 0..slider_points.len) |now, i| {
            const next = slider_points[@min(i + 1, slider_points.len - 1)];

            cp_temp_buffer.append(zm.Vec2f{ @floatFromInt(now.X), @floatFromInt(now.Y) }) catch unreachable;

            if (now.X == next.X and now.Y == next.Y) {
                if (cp_temp_buffer.items.len < 2) {
                    //full_path_buffer.appendSlice(cp_temp_buffer.items) catch unreachable;
                    continue;
                    //@breakpoint();
                }

                switch (slider_type) {
                    .Bezier => {
                        if (cp_temp_buffer.items.len >= 3) {
                            //@breakpoint();
                            const bezier = CurveApproximator.approximateBezier(allocator, cp_temp_buffer.items) catch unreachable;
                            defer allocator.free(bezier);
                            full_path_buffer.appendSlice(bezier) catch unreachable;
                        } else {
                            //2 point path is just a straight one so just add the control points as-is
                            full_path_buffer.appendSlice(cp_temp_buffer.items) catch unreachable;
                        }
                    },
                    .Linear => {
                        const linear = cp_temp_buffer.items;
                        full_path_buffer.appendSlice(linear) catch unreachable;
                    },
                    .PerfectCircle => {
                        if (cp_temp_buffer.items.len < 3)
                            @breakpoint();

                        const perfect_cirlce = CurveApproximator.approximateCircularArc(allocator, cp_temp_buffer.items) catch unreachable;
                        defer allocator.free(perfect_cirlce);
                        full_path_buffer.appendSlice(perfect_cirlce) catch unreachable;
                    },
                    .Catmull => {
                        if (cp_temp_buffer.items.len < 3)
                            @breakpoint();

                        const catmull = CurveApproximator.approximateCatmull(allocator, cp_temp_buffer.items, 50) catch unreachable;
                        defer allocator.free(catmull);
                        full_path_buffer.appendSlice(catmull) catch unreachable;
                    },
                }

                cp_temp_buffer.clearRetainingCapacity();
            }
        }

        //trim path
        var target_length = hit_object.HitSlider.?.PixelLength;
        const items = full_path_buffer.items;
        for (0..items.len - 1) |i| {
            const dist = zm.vec.distance(items[i], items[i + 1]);

            if (target_length - dist <= 0) {
                const blend = target_length / dist;

                const final_point_adjusted = zm.vec.lerp(items[i], items[i + 1], blend);

                full_path_buffer.shrinkRetainingCapacity(i + 1);
                full_path_buffer.append(final_point_adjusted) catch unreachable;
                break;
            }

            target_length -= dist;
        }

        const path_slice = full_path_buffer.toOwnedSlice() catch unreachable;

        drawable_slider.Path = Path.Init(path_slice, beatmap.CircleSizeOsuPixels);

        std.debug.print("Target: {d} Actual: {d}\n", .{ hit_object.HitSlider.?.PixelLength, drawable_slider.Path.Length });

        Profiler.End("Slider_Parse");
        const slider_texture = Texture.Init2(c.GL_TEXTURE_2D, drawable_slider.Path.Width, drawable_slider.Path.Height, c.GL_DEPTH_COMPONENT, c.GL_DEPTH_COMPONENT, c.GL_UNSIGNED_SHORT) catch unreachable;

        //const before_fbo_size = Viewport.GetSize();

        var fbo: c_uint = undefined;
        c.glGenFramebuffers(1, &fbo);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);
        c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, slider_texture.target, slider_texture.id, 0);
        //c.glFramebufferTexture2D(slider_texture.target, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint)
        //c.glFramebufferTexture2D(target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint)

        const fbo_status = c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER);

        if (fbo_status != c.GL_FRAMEBUFFER_COMPLETE) {
            //get err xd

            std.debug.print("ERROR::FBO:: Framebuffer is not complete!\n", .{});
        }

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);

        drawable_slider.FBO = fbo;
        drawable_slider.SliderTexture = slider_texture;

        OffScreenSliderRender(drawable_slider);

        return drawable_slider;
    }

    fn OffScreenSliderRender(self: *DrawableHitSlider) void {
        if (_SliderShader == null) {
            _SliderShader = Shader.Init(_SliderVertSrc, _SliderFragSrc) catch unreachable;
        }

        if (_SliderBatcher == null) {
            _SliderBatcher = PrimitiveBatcher.Init(65000, 65000) catch unreachable;
        }

        if (_SliderVtxBuffer == null) {
            _SliderVtxBuffer = VertexBuffer.Init(c.GL_ARRAY_BUFFER) catch unreachable;
        }

        if (_SliderIdxBuffer == null) {
            _SliderIdxBuffer = IndexBuffer.Init(c.GL_ELEMENT_ARRAY_BUFFER) catch unreachable;
        }

        const util = struct {
            //i will add this later
            pub inline fn placeCircle(center: zm.Vec2f, radius: f32) void {
                const SEGMENTS: u16 = 40;
                const ANGLE_STEP: f32 = 2.0 * std.math.pi / @as(f32, @floatFromInt(SEGMENTS));

                var circle_verts = _SliderBatcher.?.GetTriangleFan(SEGMENTS + 2) catch unreachable;

                circle_verts[0] = .{
                    .X = center[0],
                    .Y = center[1],
                    .Depth = 0.0,
                };

                for (0..SEGMENTS + 1) |i| {
                    const angle = @as(f32, @floatFromInt(i)) * ANGLE_STEP;

                    const x: f32 = center[0] + radius * @cos(angle);
                    const y: f32 = center[1] + radius * @sin(angle);

                    circle_verts[i + 1] = .{
                        .X = x,
                        .Y = y,
                        .Depth = -1.0,
                    };
                }
            }
            pub inline fn normalizeSafe(v: zm.Vec2f) zm.Vec2f {
                const length = zm.vec.len(v);
                if (length < 0)
                    @breakpoint();
                const len = zm.Vec2f{ length, length };
                return if (length > 0.00001) (v / len) else zm.Vec2f{ 0.0, 0.0 };
            }

            pub inline fn perpendicular(v: zm.Vec2f) zm.Vec2f {
                return .{ -v[1], v[0] };
            }
        };

        const default_viewport = Viewport.GetSize();

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.FBO);

        Viewport.SetViewportSize(self.SliderTexture.width, self.SliderTexture.height);

        c.glEnable(c.GL_DEPTH_TEST);

        c.glClear(c.GL_DEPTH_BUFFER_BIT);

        const thickness = zm.Vec2f{ self.Path.PointRadius, self.Path.PointRadius };

        const points = self.Path.Points;

        //std.debug.print("Points:\n", .{});
        //for (points, 0..) |value, i| {
        //    std.debug.print("{d}:[{d}|{d}] ", .{ i, value[0], value[1] });
        //    if (i % 8 == 7) {
        //        std.debug.print("\n", .{});
        //    }
        //}
        //
        //std.debug.print("\n", .{});
        //Profiler.Start("Slider_Geometry");
        const n = points.len;

        const double_n: u16 = @intCast(n * 2);

        var vtx_index: usize = 0;
        var rightSide = _SliderBatcher.?.GetTriangleStrip(double_n) catch return;
        var leftSide = _SliderBatcher.?.GetTriangleStrip(double_n) catch return;
        var mits: i32 = 0;
        for (0..n) |i| {
            const curr: zm.Vec2f = points[i] - self.Path.Position; //.{points[i][0] - self.Path.Position[0], points[i][1] - self}

            var nVec: zm.Vec2f = .{ 0.0, 0.0 };

            if (i == 0) {
                //start cap
                util.placeCircle(curr, thickness[0]);

                const next = points[i + 1] - self.Path.Position;
                const dir: zm.Vec2f = util.normalizeSafe(next - curr);

                nVec = util.perpendicular(dir) * thickness;
            } else if (i == n - 1) {
                //end cap
                util.placeCircle(curr, thickness[0]);

                //end point: normal from last segment
                const prev = points[i - 1] - self.Path.Position;
                const dir = util.normalizeSafe(curr - prev);

                nVec = util.perpendicular(dir) * thickness;
            } else {
                const prev = points[i - 1] - self.Path.Position;
                const next = points[i + 1] - self.Path.Position;

                const MaxMiterLength = 5.0; //max allowed miter length

                const dirPrev = util.normalizeSafe(curr - prev);
                const dirNext = util.normalizeSafe(next - curr);

                const normalPrev = util.perpendicular(dirPrev);
                const normalNext = util.perpendicular(dirNext);

                const miter = util.normalizeSafe(normalPrev + normalNext);

                //miter length scale
                const dotProduct: f32 = zm.vec.dot(miter, normalPrev);
                const miterLength = 1.0 / dotProduct;

                //if miter is above threshold just place a circle
                if (@abs(miterLength) > MaxMiterLength) {
                    mits += 1;
                    //std.debug.print("Placed circle because miter was: {d} : {d}\n", .{ miterLength, mits });

                    util.placeCircle(curr, thickness[0]);
                }

                nVec = util.normalizeSafe(normalPrev + normalNext) * thickness;

                //printf("X: %f Y: %f\n", nVec.x, nVec.y);
            }

            rightSide[vtx_index] = .{
                .X = curr[0],
                .Y = curr[1],
                .Depth = 0.0,
            };
            rightSide[vtx_index + 1] = .{
                .X = curr[0] - nVec[0],
                .Y = curr[1] - nVec[1],
                .Depth = -1.0,
            };
            //rightSide += 2;

            leftSide[vtx_index] = .{
                .X = curr[0],
                .Y = curr[1],
                .Depth = 0.0,
            };
            leftSide[vtx_index + 1] = .{
                .X = curr[0] + nVec[0],
                .Y = curr[1] + nVec[1],
                .Depth = -1.0,
            };
            vtx_index += 2;
        }
        //Profiler.End("Slider_Geometry");
        const upload_data = _SliderBatcher.?.GetUploadData();

        _SliderIdxBuffer.?.OrphanUpload(upload_data.IndexSlice, c.GL_STATIC_DRAW);
        _SliderVtxBuffer.?.OrphanUpload(upload_data.VertexSlice, c.GL_STATIC_DRAW);
        SliderVertex.EnableVertexAttribs();

        const projection = zm.Mat4f.orthographic(0.0, @floatFromInt(self.SliderTexture.width), 0.0, @floatFromInt(self.SliderTexture.height), -1.0, 1.0);

        _SliderShader.?.Use();
        _SliderShader.?.SetMat4f("u_Projection", &projection);

        c.glDrawElements(c.GL_TRIANGLES, @intCast(upload_data.IndexSlice.len), c.GL_UNSIGNED_SHORT, @ptrFromInt(0));

        //i should be zigging and using defer
        _SliderBatcher.?.ResetWritePosition();
        SliderVertex.DisableVertexAttribs();
        c.glDisable(c.GL_DEPTH_TEST);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        Viewport.SetViewportSize(default_viewport[0], default_viewport[1]);
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

    fn calculateAlpha(self: *DrawableHitSlider, song_pos: f32) f32 {
        const FADEOUT: f32 = 241.0;

        const fade_in_start: f32 = @floatFromInt(self.HitObject.StartTime - self.Beatmap.Preempt);
        const fade_in_duration: f32 = @floatFromInt(self.Beatmap.FadeIn);
        const fade_in_end: f32 = fade_in_start + fade_in_duration;

        const slider_end: f32 = @floatFromInt(self.HitObject.HitSlider.?.EndTime);

        const fade_out_start = slider_end;
        const fade_out_end = slider_end + FADEOUT;

        var alpha: f32 = 1.0;

        if (song_pos <= fade_in_end) {
            alpha = MathUtils.Map(song_pos, fade_in_start, fade_in_end, 0.0, 1.0);
        } else if (song_pos >= fade_out_start) {
            alpha = MathUtils.Map(song_pos, fade_out_start, fade_out_end, 1.0, 0.0);
        }

        return alpha;
    }

    pub fn Draw(selfP: *anyopaque, g: *Graphics) void {
        const self: *@This() = @ptrCast(@alignCast(selfP));

        const FADEOUT: f32 = 241.0;

        //todo add snaking sometime, it's pretty easy
        //self.OffScreenSliderRender();

        const song_pos: f32 = @floatCast(self.Beatmap.Song.GetPlaybackPositionInSeconds() * 1000.0);

        const fade_in_start: f32 = @floatFromInt(self.HitObject.StartTime - self.Beatmap.Preempt);
        const fade_in_duration: f32 = @floatFromInt(self.Beatmap.FadeIn);
        const fade_in_end: f32 = fade_in_start + fade_in_duration;

        var fade_in_progress = MathUtils.Map(song_pos, fade_in_start, fade_in_end, 0.0, 1.0);
        fade_in_progress = std.math.clamp(fade_in_progress, 0.0, 1.0);

        const slider_start: f32 = @floatFromInt(self.HitObject.StartTime);
        const slider_end: f32 = @floatFromInt(self.HitObject.HitSlider.?.EndTime);

        const fade_out_start = slider_end;
        const fade_out_end = slider_end + FADEOUT;

        var fade_out_progress = MathUtils.Map(song_pos, fade_out_start, fade_out_end, 0.0, 1.0);
        fade_out_progress = std.math.clamp(fade_out_progress, 0.0, 1.0);
        const sliderbody_alpha = calculateAlpha(self, song_pos);

        if (song_pos >= fade_out_end)
            self.IsDead = true;

        const slide_count: f32 = @floatFromInt(self.HitObject.HitSlider.?.Slides);
        const slide_duration = (slider_end - slider_start) / slide_count;
        const sliderball_progress = MathUtils.Oscillate01(MathUtils.Map(song_pos, slider_start, slider_start + slide_duration, 0.0, 1.0));

        const slider_texture_draw_pos = PlayableBeatmap.MapSliderToPlayfield(self.Path.Bounds);

        const stacking_vector = zm.Vec2f{ self.Beatmap.CircleSizeOsuPixels / 5.0, self.Beatmap.CircleSizeOsuPixels / 5.0 };
        const stacking_count = zm.Vec2f{ @floatFromInt(self.HitObject.StackCount), @floatFromInt(self.HitObject.StackCount) };

        const stacking_offset = stacking_vector * stacking_count;

        g.DrawRect(slider_texture_draw_pos, .{ 10.0, 1.0, 1.0, sliderbody_alpha }, &self.SliderTexture, .{ 0.0, 0.0, 1.0, 1.0 });

        DrawableHitCircle.DrawHitCircle(g, self.Beatmap, &self.HitObject, stacking_offset, song_pos);

        //for (self.Path.Points) |curve_point| {
        //    const draw_pos = PlayableBeatmap.MapToPlayfield2(curve_point[0], curve_point[1]);
        //
        //    g.DrawRectangleCentered(draw_pos, .{ 8.0, 8.0 }, .{ 1.0, 0.0, 0.5, 1.0 }, PlayScene.GetSkin().DotTexture, .{ 0.0, 0.0, 1.0, 1.0 });
        //}

        if (song_pos >= slider_start and song_pos <= slider_end) {
            var sliderball_pos = self.Path.CalculatePositionAt(self.HitObject.HitSlider.?.PixelLength * sliderball_progress);
            sliderball_pos = PlayableBeatmap.MapToPlayfield2(sliderball_pos[0], sliderball_pos[1]);

            const sliderball_size = self.Beatmap.GetWorldCircleSize();

            g.DrawRectangleCentered(sliderball_pos, sliderball_size, .{ 1.0, 1.0, 1.0, 1.0 }, &PlayScene.GetSkin().SliderBall.BackingTexture, .{ 0.0, 0.0, 1.0, 1.0 });
        }
    }
};
