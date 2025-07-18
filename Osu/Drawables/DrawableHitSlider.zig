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
        //Profiler.Start("Slider_Parse");
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

        //std.debug.print("Target: {d} Actual: {d}\n", .{ hit_object.HitSlider.?.PixelLength, drawable_slider.Path.Length });

        //Profiler.End("Slider_Parse");
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

            pub inline fn drawLineSegment(start: zm.Vec2f, end: zm.Vec2f, perpendicular: zm.Vec2f, half_thickness: zm.Vec2f) void {
                const offset = perpendicular * half_thickness;

                const top_side = _SliderBatcher.?.GetQuad();

                top_side[0].X = start[0] + offset[0];
                top_side[0].Y = start[1] + offset[1];
                top_side[0].Depth = -1.0;

                top_side[1].X = start[0];
                top_side[1].Y = start[1];
                top_side[1].Depth = 0.0;

                top_side[2].X = end[0];
                top_side[2].Y = end[1];
                top_side[2].Depth = 0.0;

                top_side[3].X = end[0] + offset[0];
                top_side[3].Y = end[1] + offset[1];
                top_side[3].Depth = -1.0;

                const bottom_size = _SliderBatcher.?.GetQuad();

                bottom_size[0].X = start[0] - offset[0];
                bottom_size[0].Y = start[1] - offset[1];
                bottom_size[0].Depth = -1.0;

                bottom_size[1].X = start[0];
                bottom_size[1].Y = start[1];
                bottom_size[1].Depth = 0.0;

                bottom_size[2].X = end[0];
                bottom_size[2].Y = end[1];
                bottom_size[2].Depth = 0.0;

                bottom_size[3].X = end[0] - offset[0];
                bottom_size[3].Y = end[1] - offset[1];
                bottom_size[3].Depth = -1.0;
            }

            pub inline fn drawCornerJointDynamic(center: zm.Vec2f, prev_perpendicular: zm.Vec2f, curr_perpendicular: zm.Vec2f, half_thickness: zm.Vec2f) void {
                const cross = prev_perpendicular[0] * curr_perpendicular[1] - prev_perpendicular[1] * curr_perpendicular[0];

                const is_left_turn = if (cross > 0.0) true else false;

                var start_offset = if (is_left_turn) prev_perpendicular else -prev_perpendicular;
                start_offset *= half_thickness;
                var end_offset = if (is_left_turn) curr_perpendicular else -curr_perpendicular;
                end_offset *= half_thickness;

                const start_angle = std.math.atan2(start_offset[1], start_offset[0]);
                const end_angle = std.math.atan2(end_offset[1], end_offset[0]);

                var angle_diff = end_angle - start_angle;

                if (angle_diff > std.math.pi) {
                    angle_diff -= 2.0 * std.math.pi;
                } else if (angle_diff < -std.math.pi) {
                    angle_diff += 2.0 * std.math.pi;
                }

                const abs_angle_diff = @abs(angle_diff);

                const MIN_RESOLUTION: comptime_float = 3.0;
                const MAX_RESOLUTION: comptime_float = 32.0;
                const RESOLUTION_SCALE: comptime_float = 8.0;

                const resolution = @max(MIN_RESOLUTION, @min(MAX_RESOLUTION, abs_angle_diff * RESOLUTION_SCALE));

                const resolutionInt: u16 = @intFromFloat(resolution);

                var triangle_fan = _SliderBatcher.?.GetTriangleFan(resolutionInt + 2) catch unreachable;
                triangle_fan[0].X = center[0];
                triangle_fan[0].Y = center[1];
                triangle_fan[0].Depth = 0.0;

                const clockwise: bool = angle_diff < 0.0;

                for (0..resolutionInt + 1) |i| {
                    const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(resolutionInt));
                    const angle = if (clockwise) start_angle - t * abs_angle_diff else start_angle + t * angle_diff;

                    const offset = zm.Vec2f{ @cos(angle), @sin(angle) } * half_thickness;

                    triangle_fan[i + 1].X = center[0] + offset[0];
                    triangle_fan[i + 1].Y = center[1] + offset[1];
                    triangle_fan[i + 1].Depth = -1.0;
                }
            }
        };

        const default_viewport = Viewport.GetSize();

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.FBO);

        Viewport.SetViewportSize(self.SliderTexture.width, self.SliderTexture.height);

        c.glEnable(c.GL_DEPTH_TEST);

        c.glClear(c.GL_DEPTH_BUFFER_BIT);

        //const thickness = zm.Vec2f{ self.Path.PointRadius, self.Path.PointRadius };
        const points = self.Path.Points;
        const half_thickness: zm.Vec2f = .{ self.Path.PointRadius, self.Path.PointRadius };

        var prev_perpendicular: zm.Vec2f = .{ 0.0, 0.0 };
        //Profiler.Start("Slider_Geometry");
        //start cap
        util.placeCircle(points[0] - self.Path.Position, half_thickness[0]);
        //end cap
        util.placeCircle(points[points.len - 1] - self.Path.Position, half_thickness[0]);
        for (0..points.len - 1) |i| {
            const current = points[i] - self.Path.Position;
            var next = points[i + 1] - self.Path.Position;

            if (@reduce(.And, current == next)) {
                //nudge hax
                next[0] += 0.1;
                next[1] += 0.1;
            }

            const direction = zm.vec.normalize(next - current);
            const perpendicular: zm.Vec2f = .{ direction[1], -direction[0] };

            //draw line segment
            util.drawLineSegment(current, next, perpendicular, half_thickness);
            if (i > 0) {
                //draw corner
                util.drawCornerJointDynamic(current, prev_perpendicular, perpendicular, half_thickness);
            }

            prev_perpendicular = perpendicular;
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

        const stacking_count = zm.Vec2f{ @floatFromInt(self.HitObject.StackCount), @floatFromInt(self.HitObject.StackCount) };

        const stacking_offset = self.Beatmap.GetStackVector() * stacking_count;

        //slider_texture_draw_pos[0] += stacking_vector[0];
        //slider_texture_draw_pos[1] += stacking_vector[0];

        g.DrawRect(slider_texture_draw_pos, .{ 10.0, 1.0, 1.0, sliderbody_alpha }, &self.SliderTexture, .{ 0.0, 0.0, 1.0, 1.0 });

        DrawableHitCircle.DrawHitCircle(g, self.Beatmap, &self.HitObject, stacking_offset, song_pos);

        //for (self.Path.Points) |curve_point| {
        //    const draw_pos = PlayableBeatmap.MapToPlayfield2(curve_point[0], curve_point[1]);
        //
        //    g.DrawRectangleCentered(draw_pos, .{ 8.0, 8.0 }, .{ 1.0, 0.0, 0.5, 1.0 }, PlayScene.GetSkin().DotTexture, .{ 0.0, 0.0, 1.0, 1.0 });
        //}

        if (song_pos >= slider_start and song_pos <= slider_end) {
            var sliderball_pos = self.Path.CalculatePositionAt(self.Path.Length * sliderball_progress);
            sliderball_pos = PlayableBeatmap.MapToPlayfield2(sliderball_pos[0], sliderball_pos[1]);

            const sliderball_size = self.Beatmap.GetWorldCircleSize();

            g.DrawRectangleCentered(sliderball_pos, sliderball_size, .{ 1.0, 1.0, 1.0, 1.0 }, &PlayScene.GetSkin().SliderBall.BackingTexture, .{ 0.0, 0.0, 1.0, 1.0 });
        }
    }
};
