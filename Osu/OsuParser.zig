const std = @import("std");

pub const OsuMode = enum(u8) {
    Standard = 0,
    Taiko = 1,
    Catch = 2,
    Mania = 3,
};

pub const GeneralSection = struct {
    AudioFilename: []const u8 = "",
    AudioLeadIn: i32 = 0,
    PreviewTime: i32 = -1,
    Countdown: i32 = 1,
    SampleSet: []const u8 = "Normal",
    StackLeniency: f32 = 0.7,
    Mode: OsuMode = .Standard,
};

pub const MetadataSection = struct {
    Title: []const u8 = "",
    TitleUnicode: []const u8 = "",
    Artist: []const u8 = "",
    ArtistUnicode: []const u8 = "",
    Creator: []const u8 = "",
    Version: []const u8 = "",
    Source: []const u8 = "",
    Tags: []const u8 = "",
    BeatmapID: i32 = -1,
    BeatmapSetID: i32 = -1,
};

pub const DifficultySection = struct {
    HPDrainRate: f32 = -1,
    CircleSize: f32 = -1,
    OverallDifficulty: f32 = -1,
    ApproachRate: f32 = -1,
    SliderMultiplier: f32 = -1,
    SliderTickRate: f32 = -1,
};

pub const TimingPointSampleSet = enum(u8) {
    Default = 0,
    Normal = 1,
    Soft = 2,
    Drum = 3,
};

pub const TimingPoint = struct {
    Time: i32,
    BeatLength: f32,
    BeatMultiplier: f32,
    Meter: i32,
    SampleSet: TimingPointSampleSet,
    SamepleIndex: i32,
    Volume: i32,
    Inherited: bool,
    IsKiai: bool,
};

pub const HitSoundSet = struct {
    Bits: u8,

    pub fn Has(self: HitSoundSet, hs: HitSound) bool {
        return (self.bits & @intFromEnum(hs)) != 0;
    }

    pub fn Add(self: *HitSoundSet, hs: HitSound) void {
        self.bits |= @intFromEnum(hs);
    }
};

pub const HitSound = enum(u8) {
    Default = 0,
    Normal = 1,
    Whistle = 2,
    Finish = 4,
    Clap = 8,
};

pub const HitCircle = struct {};
pub const HitSpinner = struct {
    EndTime: i32,
};

pub const HitSliderType = enum(u8) {
    Bezier = 'B',
    Catmull = 'C',
    Linear = 'L',
    PerfectCircle = 'P',
};

pub const SliderCurvePoint = struct { X: i32, Y: i32 };

pub const HitObject = struct {
    X: i32,
    Y: i32,
    StartTime: i32,
    HitSoundSet: HitSoundSet,
    IsNewCombo: bool,
    HitCircle: ?HitCircle,
    HitSlider: ?HitSlider,
    HitSpinner: ?HitSpinner,
    StackCount: i32 = 0,

    pub fn IsSpinner(self: *const HitObject) bool {
        return self.HitSpinner != null;
    }

    pub fn IsHitCircle(self: *const HitObject) bool {
        return self.HitCircle != null;
    }

    pub fn IsHitSlider(self: *const HitObject) bool {
        return self.HitSlider != null;
    }

    ///if spinner or slider returns .EndTime otherwise returns .StartTime
    pub fn GetEndTime(self: *const HitObject) i32 {
        if (self.IsHitSlider())
            return self.HitSlider.?.EndTime;

        if (self.IsSpinner())
            return self.HitSpinner.?.EndTime;

        //otherwise just return starttime
        return self.StartTime;
    }

    pub fn Distance(self_x: i32, self_y: i32, other_x: i32, other_y: i32) i32 {
        const dx: i32 = self_x - other_x;
        const dy: i32 = self_y - other_y;
        const dist_f: f64 = @floatFromInt(dx * dx + dy * dy);

        return @intFromFloat(@round(@sqrt(dist_f)));
    }
};

pub const HitSlider = struct {
    Type: HitSliderType,
    CurvePoints: std.ArrayList(SliderCurvePoint),
    Slides: i32,
    PixelLength: f32,
    EndTime: i32,
};

const Profiler = @import("../Profiler.zig").Profiler;

pub const Beatmap = struct {
    General: GeneralSection,
    Metadata: MetadataSection,
    Difficulty: DifficultySection,

    TimingPoints: std.ArrayList(TimingPoint),
    HitObjects: std.ArrayList(HitObject),

    m_Allocator: std.mem.Allocator,

    pub fn FromString(allocator: std.mem.Allocator, string: []const u8) Beatmap {
        Profiler.Start("parse_beatmap");
        //Go through every line and detect each section etc
        //...
        //init beatmap struct and fill in the fields
        // return beatmap

        var lines = std.mem.splitAny(u8, string, "\n");

        var generalSection = GeneralSection{};
        var metadataSection = MetadataSection{};
        var difficultySection = DifficultySection{};
        var timingPoints = std.ArrayList(TimingPoint).init(allocator);
        var hitObjects = std.ArrayList(HitObject).init(allocator);
        var current_section: ?[]const u8 = null;

        var last_uninherited_beat_length: f32 = 0.0;

        while (lines.next()) |line_raw| {
            //Trim out useless junk from each line
            const line = std.mem.trim(u8, line_raw, " \r\n");
            //Skip comments and empty lines
            if (line.len == 0 or line[0] == '#') continue;

            //current line is a section change mark
            if (line.len >= 2 and line[0] == '[' and line[line.len - 1] == ']') {
                current_section = line[1 .. line.len - 1];
                continue;
            }

            if (current_section) |section| {
                if (std.mem.eql(u8, section, "General")) {
                    parseGeneralSection(allocator, line, &generalSection);
                } else if (std.mem.eql(u8, section, "Metadata")) {
                    parseMetadataSection(allocator, line, &metadataSection);
                } else if (std.mem.eql(u8, section, "Difficulty")) {
                    parseDifficultySection(line, &difficultySection);
                } else if (std.mem.eql(u8, section, "TimingPoints")) {
                    if (parseTimingPoint(line, &last_uninherited_beat_length)) |tp| {
                        timingPoints.append(tp) catch {};
                    } else {
                        std.debug.print("Failed to parse timingpoint: {s}", .{line});
                    }
                } else if (std.mem.eql(u8, section, "HitObjects")) {
                    var ho: ?HitObject = parseHitObject(allocator, line);

                    if (ho != null) {
                        //god this is ugly
                        if (ho.?.HitSlider != null) {
                            const slider_tp = GetTimingPointAt(&timingPoints, ho.?.StartTime);
                            const duration = ho.?.HitSlider.?.PixelLength / (difficultySection.SliderMultiplier * 100.0 * slider_tp.BeatMultiplier) * slider_tp.BeatLength * @as(f32, @floatFromInt(ho.?.HitSlider.?.Slides));

                            ho.?.HitSlider.?.EndTime = ho.?.StartTime + @as(i32, @intFromFloat(duration));
                            //std.debug.print("PixelLength: {d}  BeatLength: {d}, Slider Duration: {d}, Slider.Endtime: {d}\n", .{ ho.?.HitSlider.?.PixelLength, slider_tp.BeatLength, duration, ho.?.HitSlider.?.EndTime });
                        }
                        hitObjects.append(ho.?) catch {};
                    } else {
                        std.debug.print("Failed to parse hitobject: {s}", .{line});
                    }
                }
            }
        }
        Profiler.End("parse_beatmap");
        return Beatmap{
            .General = generalSection,
            .Metadata = metadataSection,
            .Difficulty = difficultySection,
            .TimingPoints = timingPoints,
            .HitObjects = hitObjects,
            .m_Allocator = allocator,
        };
    }

    fn parseGeneralSection(allocator: std.mem.Allocator, line: []const u8, section: *GeneralSection) void {
        const colon_pos = std.mem.indexOf(u8, line, ":") orelse return;
        const key = line[0..colon_pos];
        const value = std.mem.trim(u8, line[colon_pos + 1 ..], " ");

        const key_hash = std.hash_map.hashString(key);
        switch (key_hash) {
            std.hash_map.hashString("AudioFilename") => section.AudioFilename = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("AudioLeadIn") => section.AudioLeadIn = std.fmt.parseInt(i32, value, 10) catch 0,
            std.hash_map.hashString("PreviewTime") => section.PreviewTime = std.fmt.parseInt(i32, value, 10) catch -1,
            std.hash_map.hashString("Countdown") => section.Countdown = std.fmt.parseInt(i32, value, 10) catch 1,
            std.hash_map.hashString("SampleSet") => section.SampleSet = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("StackLeniency") => section.StackLeniency = std.fmt.parseFloat(f32, value) catch 0.7,
            std.hash_map.hashString("Mode") => section.Mode = @enumFromInt(std.fmt.parseInt(i32, value, 10) catch 0),
            //std.hash_map.hashString("LetterboxInBreaks") => section.LetterboxInBreaks = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true"),
            //std.hash_map.hashString("UseSkinSprites") => section.UseSkinSprites = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true"),
            //std.hash_map.hashString("OverlayPosition") => section.OverlayPosition = value,
            //std.hash_map.hashString("SkinPreference") => section.SkinPreference = value,
            //std.hash_map.hashString("EpilepsyWarning") => section.EpilepsyWarning = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true"),
            //std.hash_map.hashString("CountdownOffset") => section.CountdownOffset = std.fmt.parseInt(i32, value, 10) catch 0,
            //std.hash_map.hashString("SpecialStyle") => section.SpecialStyle = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true"),
            //std.hash_map.hashString("WidescreenStoryboard") => section.WidescreenStoryboard = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true"),
            //std.hash_map.hashString("SamplesMatchPlaybackRate") => section.SamplesMatchPlaybackRate = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true"),
            else => {},
        }
    }

    fn parseMetadataSection(allocator: std.mem.Allocator, line: []const u8, section: *MetadataSection) void {
        const colon_pos = std.mem.indexOf(u8, line, ":") orelse return;
        const key = line[0..colon_pos];
        const value = std.mem.trim(u8, line[colon_pos + 1 ..], " ");

        const key_hash = std.hash_map.hashString(key);
        switch (key_hash) {
            std.hash_map.hashString("Title") => section.Title = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("TitleUnicode") => section.TitleUnicode = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("Artist") => section.Artist = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("ArtistUnicode") => section.ArtistUnicode = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("Creator") => section.Creator = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("Version") => section.Version = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("Source") => section.Source = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("Tags") => section.Tags = allocator.dupe(u8, value) catch unreachable,
            std.hash_map.hashString("BeatmapID") => section.BeatmapID = std.fmt.parseInt(i32, value, 10) catch 0,
            std.hash_map.hashString("BeatmapSetID") => section.BeatmapSetID = std.fmt.parseInt(i32, value, 10) catch 0,
            else => {},
        }
    }

    fn parseDifficultySection(line: []const u8, section: *DifficultySection) void {
        const colon_pos = std.mem.indexOf(u8, line, ":") orelse return;
        const key = line[0..colon_pos];
        const value = std.mem.trim(u8, line[colon_pos + 1 ..], " ");

        const key_hash = std.hash_map.hashString(key);
        switch (key_hash) {
            std.hash_map.hashString("HPDrainRate") => section.HPDrainRate = std.fmt.parseFloat(f32, value) catch 5.0,
            std.hash_map.hashString("CircleSize") => section.CircleSize = std.fmt.parseFloat(f32, value) catch 5.0,
            std.hash_map.hashString("OverallDifficulty") => section.OverallDifficulty = std.fmt.parseFloat(f32, value) catch 5.0,
            std.hash_map.hashString("ApproachRate") => section.ApproachRate = std.fmt.parseFloat(f32, value) catch 5.0,
            std.hash_map.hashString("SliderMultiplier") => section.SliderMultiplier = std.fmt.parseFloat(f32, value) catch 1.4,
            std.hash_map.hashString("SliderTickRate") => section.SliderTickRate = std.fmt.parseFloat(f32, value) catch 1.0,
            else => {},
        }
    }

    fn parseTimingPoint(line: []const u8, last_uninherited: *f32) ?TimingPoint {
        var parts = std.mem.splitAny(u8, line, ",");

        const time_str = parts.next() orelse return null;
        const beat_length_str = parts.next() orelse return null;
        const meter_str = parts.next() orelse "4";
        const sample_set_str = parts.next() orelse "0";
        const sample_index_str = parts.next() orelse "0";
        const volume_str = parts.next() orelse "100";
        const uninherited_str = parts.next() orelse "1";
        const effects_str = parts.next() orelse "0";

        const time = std.fmt.parseInt(i32, std.mem.trim(u8, time_str, " "), 10) catch return null;
        var beat_length = std.fmt.parseFloat(f32, std.mem.trim(u8, beat_length_str, " ")) catch return null;
        const meter = std.fmt.parseInt(i32, std.mem.trim(u8, meter_str, " "), 10) catch 4;
        const sample_set = std.fmt.parseInt(i32, std.mem.trim(u8, sample_set_str, " "), 10) catch 0;
        const sample_index = std.fmt.parseInt(i32, std.mem.trim(u8, sample_index_str, " "), 10) catch 0;
        const volume = std.fmt.parseInt(i32, std.mem.trim(u8, volume_str, " "), 10) catch 100;
        const uninherited = std.fmt.parseInt(i32, std.mem.trim(u8, uninherited_str, " "), 10) catch 1;
        const effects = std.fmt.parseInt(i32, std.mem.trim(u8, effects_str, " "), 10) catch 0;

        const isKiai = effects & 1 == 1;

        const isInherited = (uninherited == 0);

        var beatMultiplier: f32 = 1.0;

        if (isInherited) {
            beatMultiplier = (100.0 / @abs(beat_length));
            beat_length = last_uninherited.*;
        } else {
            last_uninherited.* = beat_length;
        }

        return TimingPoint{
            .Time = time,
            .BeatLength = beat_length,
            .BeatMultiplier = beatMultiplier,
            .Meter = meter,
            .SampleSet = @enumFromInt(sample_set),
            .SamepleIndex = sample_index,
            .Volume = volume,
            .Inherited = isInherited,
            .IsKiai = isKiai,
        };
    }

    pub fn GetTimingPointAt(timingPoints: *const std.ArrayList(TimingPoint), offset: i32) TimingPoint {
        var samplingPointIndex: usize = 0;

        for (0..timingPoints.*.items.len) |i| {
            if (timingPoints.*.items[i].Time <= offset) {
                samplingPointIndex = i;
            } else {
                break;
            }
        }

        return timingPoints.*.items[samplingPointIndex];
    }

    fn parseHitObject(allocator: std.mem.Allocator, line: []const u8) ?HitObject {
        var parts = std.mem.splitAny(u8, line, ",");

        const x_str = parts.next() orelse return null;
        const y_str = parts.next() orelse return null;
        const time_str = parts.next() orelse return null;
        const type_str = parts.next() orelse return null;
        const hit_sound_str = parts.next() orelse return null;

        const x = std.fmt.parseInt(i32, std.mem.trim(u8, x_str, " "), 10) catch return null;
        const y = std.fmt.parseInt(i32, std.mem.trim(u8, y_str, " "), 10) catch return null;
        const time = std.fmt.parseInt(i32, std.mem.trim(u8, time_str, " "), 10) catch return null;
        const obj_type = std.fmt.parseInt(u8, std.mem.trim(u8, type_str, " "), 10) catch return null;
        const hit_sound_raw = std.fmt.parseInt(u8, std.mem.trim(u8, hit_sound_str, " "), 10) catch return null;
        //std.debug.print("HitSoundRaw: {d}", .{hit_sound_raw});
        // Parse hit sound enum
        const hit_sound_set: HitSoundSet = .{ .Bits = hit_sound_raw }; //@enumFromInt(hit_sound_raw);

        // Check if it's a new combo (bit 2)
        const is_new_combo = (obj_type & 4) != 0;

        // Determine object type (bits 0, 1, 3)
        const base_type = obj_type & 0x8B; // Remove new combo and skip bits

        var hit_circle: ?HitCircle = null;
        var hit_slider: ?HitSlider = null;
        var hit_spinner: ?HitSpinner = null;

        if (base_type & 1 != 0) {
            // Hit Circle
            hit_circle = HitCircle{};
        } else if (base_type & 2 != 0) {
            // Slider
            const slider_data = parts.next() orelse return null;
            const slides_str = parts.next() orelse "1";
            const length_str = parts.next() orelse "0";

            hit_slider = parseSlider(allocator, slider_data, slides_str, length_str) catch return null;
        } else if (base_type & 8 != 0) {
            // Spinner
            const end_time_str = parts.next() orelse return null;
            const end_time = std.fmt.parseInt(i32, std.mem.trim(u8, end_time_str, " "), 10) catch return null;

            hit_spinner = HitSpinner{
                .EndTime = end_time,
            };
        }

        return HitObject{
            .X = x,
            .Y = y,
            .StartTime = time,
            .HitSoundSet = hit_sound_set,
            .IsNewCombo = is_new_combo,
            .HitCircle = hit_circle,
            .HitSlider = hit_slider,
            .HitSpinner = hit_spinner,
        };
    }

    fn parseSlider(allocator: std.mem.Allocator, slider_data: []const u8, slides_str: []const u8, length_str: []const u8) !HitSlider {
        var slider_parts = std.mem.splitAny(u8, slider_data, "|");

        // First part is the curve type
        const curve_type_str = slider_parts.next() orelse return error.InvalidSliderData;
        const curve_type: HitSliderType = switch (curve_type_str[0]) {
            'B' => HitSliderType.Bezier,
            'C' => HitSliderType.Catmull,
            'L' => HitSliderType.Linear,
            'P' => HitSliderType.PerfectCircle,
            else => return error.InvalidSliderData,
        };

        // Parse curve points
        var curve_points = std.ArrayList(SliderCurvePoint).init(allocator);
        while (slider_parts.next()) |point_str| {
            var point_parts = std.mem.splitAny(u8, point_str, ":");
            const x_str = point_parts.next() orelse continue;
            const y_str = point_parts.next() orelse continue;

            const x = std.fmt.parseInt(i32, std.mem.trim(u8, x_str, " "), 10) catch continue;
            const y = std.fmt.parseInt(i32, std.mem.trim(u8, y_str, " "), 10) catch continue;

            try curve_points.append(SliderCurvePoint{ .X = x, .Y = y });
        }

        const slides = std.fmt.parseInt(i32, std.mem.trim(u8, slides_str, " "), 10) catch 1;
        const pixelLength = std.fmt.parseFloat(f32, std.mem.trim(u8, length_str, " ")) catch 0.0;
        //If the slider's length is longer than the defined curve,
        //the slider will extend in a straight line from the end of the curve until it reaches the target length.

        //const end_time

        return HitSlider{
            .Type = curve_type,
            .CurvePoints = curve_points,
            .Slides = slides,
            .PixelLength = pixelLength,
            .EndTime = -1, //this would need to be calculated based on timing points
        };
    }

    pub fn StackObjectsPass(beatmap: *Beatmap) void {
        //for now we'll just use the settings used for when the map was created..
        //..and not really worrying about when we change these settings and having to re-stack

        const STACK_LENIENCE: i32 = 3;

        const objects = beatmap.HitObjects.items;

        const preempt = MapDifficultyRange(beatmap.Difficulty.ApproachRate, 1800.0, 1200.0, 450.0);
        const stack_leniency = beatmap.General.StackLeniency;

        const preempt_scaled_i32: i32 = @intFromFloat(preempt * stack_leniency);
        var i = objects.len;
        while (i > 0) {
            i -= 1;

            var n: i32 = @intCast(i);
            // We should check every note which has not yet got a stack.
            // Consider the case we have two interwound stacks and this will make sense.
            //
            // o <-1      o <-2
            //  o <-3      o <-4
            //
            // We first process starting from 4 and handle 2,
            // then we come backwards on the i loop iteration until we reach 3 and handle 1.
            // 2 and 1 will be ignored in the i loop because they already have a stack value.
            //

            var objectI: *HitObject = &objects[i];

            if (objectI.StackCount != 0 or objectI.IsSpinner()) continue;

            //HitObjectSpannable spanN = objectN as HitObjectSpannable; tf is a hitobject spannable???

            //is hitcircle
            if (objectI.IsHitCircle()) {
                while (n > 0) {
                    n -= 1;

                    var objectN: *HitObject = &objects[@intCast(n)];

                    if (objectN.IsSpinner()) continue;

                    if (objectI.StartTime - preempt_scaled_i32 > objectN.GetEndTime()) {
                        //We are no longer within stacking range of the previous object.
                        break;
                    }

                    // This is a special case where hticircles are moved DOWN and RIGHT (negative stacking) if they are under the *last* slider in a stacked pattern.
                    //    o==o <- slider is at original location
                    //        o <- hitCircle has stack of -1
                    //         o <- hitCircle has stack of -2
                    //

                    // if (spanN != null && pMathHelper.Distance(spanN.EndPosition, objectI.Position) < STACK_LENIENCE)
                    // todo special slider check for objectN
                    if (objectN.HitSlider) |slider| {
                        const i_end = slider.CurvePoints.items.len - 1;

                        const objectN_x = slider.CurvePoints.items[i_end].X;
                        const objectN_y = slider.CurvePoints.items[i_end].Y;

                        const offset = objectI.StackCount - objectN.StackCount + 1;

                        for (@intCast(n + 1)..@intCast(i + 1)) |j| {

                            //For each object which was declared under this slider, we will offset it to appear *below* the slider end (rather than above).
                            if (HitObject.Distance(objectN_x, objectN_y, objects[j].X, objects[j].Y) < STACK_LENIENCE) {
                                objects[j].StackCount -= offset;
                            }
                        }
                    }

                    if (HitObject.Distance(objectN.X, objectN.Y, objectI.X, objectI.Y) < STACK_LENIENCE) {
                        //Keep processing as if there are no sliders.  If we come across a slider, this gets cancelled out.
                        //NOTE: Sliders with start positions stacking are a special case that is also handled here.

                        objectN.StackCount = objectI.StackCount + 1;
                        objectI = objectN;
                    }
                }
            } else if (objectI.IsHitSlider()) {
                while (n > 0) {
                    n -= 1;

                    var objectN: *HitObject = &objects[@intCast(n)];

                    if (objectN.IsSpinner()) continue;

                    if (objectI.StartTime - preempt_scaled_i32 > objectN.StartTime) {
                        //We are no longer within stacking range of the previous object.
                        break;
                    }

                    var objectN_x = objectN.X;
                    var objectN_y = objectN.Y;

                    if (objectN.HitSlider) |slider| {
                        const i_end = slider.CurvePoints.items.len - 1;

                        objectN_x = slider.CurvePoints.items[i_end].X;
                        objectN_y = slider.CurvePoints.items[i_end].Y;
                    }

                    if (HitObject.Distance(objectN_x, objectN_y, objectI.X, objectI.Y) < STACK_LENIENCE) {
                        objectN.StackCount = objectI.StackCount + 1;
                        objectI = objectN;
                    }
                }
            }
        }

        //std.debug.print("[HitObjects] ({d} objects)\n", .{beatmap.HitObjects.items.len});
        //for (beatmap.HitObjects.items, 0..) |obj, index| {
        //    const obj_type = if (obj.IsHitCircle()) "HitCircle" else if (obj.IsHitSlider()) "HitSlider" else "HitSpinner";
        //
        //    std.debug.print("  {d}: [{s}] ({d},{d}) StackCount={d} Time={d}, HitSound={d}, NewCombo={}\n", .{ index, obj_type, obj.X, obj.Y, obj.StackCount, obj.StartTime, obj.HitSoundSet.Bits, obj.IsNewCombo });
        //}
        //std.debug.print("\n", .{});
    }

    pub fn MapDifficultyRange(difficulty: f32, min: f32, mid: f32, max: f32) f32 {
        if (difficulty > 5.0)
            return mid + (max - mid) * (difficulty - 5.0) / 5.0;

        if (difficulty < 5.0)
            return mid - (mid - min) * (5.0 - difficulty) / 5.0;

        return mid;
    }

    pub fn Deinit(self: *Beatmap) void {
        //clean up slider curve points
        for (self.HitObjects.items) |obj| {
            if (obj.HitSlider) |slider| {
                slider.CurvePoints.deinit();
            }
        }

        self.TimingPoints.deinit();
        self.HitObjects.deinit();

        self.m_Allocator.free(self.General.AudioFilename);
        self.m_Allocator.free(self.General.SampleSet);

        self.m_Allocator.free(self.Metadata.Artist);
        self.m_Allocator.free(self.Metadata.ArtistUnicode);
        self.m_Allocator.free(self.Metadata.Creator);
        self.m_Allocator.free(self.Metadata.Source);
        self.m_Allocator.free(self.Metadata.Tags);
        self.m_Allocator.free(self.Metadata.Title);
        self.m_Allocator.free(self.Metadata.TitleUnicode);
        self.m_Allocator.free(self.Metadata.Version);
    }

    pub fn print(self: *const Beatmap) void {
        std.debug.print("=== OSU BEATMAP ===\n\n", .{});

        //pint General Section
        std.debug.print("[General]\n", .{});
        std.debug.print("  AudioFilename: {s}\n", .{self.General.AudioFilename});
        std.debug.print("  AudioLeadIn: {d}\n", .{self.General.AudioLeadIn});
        std.debug.print("  PreviewTime: {d}\n", .{self.General.PreviewTime});
        std.debug.print("  Countdown: {d}\n", .{self.General.Countdown});
        std.debug.print("  SampleSet: {s}\n", .{self.General.SampleSet});
        std.debug.print("  StackLeniency: {d:.2}\n", .{self.General.StackLeniency});
        std.debug.print("  Mode: {s}\n", .{@tagName(self.General.Mode)});
        //std.debug.print("  LetterboxInBreaks: {}\n", .{self.General.LetterboxInBreaks});
        //std.debug.print("  UseSkinSprites: {}\n", .{self.General.UseSkinSprites});
        //std.debug.print("  OverlayPosition: {s}\n", .{self.General.OverlayPosition});
        //std.debug.print("  SkinPreference: {s}\n", .{self.General.SkinPreference});
        //std.debug.print("  EpilepsyWarning: {}\n", .{self.General.EpilepsyWarning});
        //std.debug.print("  CountdownOffset: {d}\n", .{self.General.CountdownOffset});
        //std.debug.print("  SpecialStyle: {}\n", .{self.General.SpecialStyle});
        //std.debug.print("  WidescreenStoryboard: {}\n", .{self.General.WidescreenStoryboard});
        //std.debug.print("  SamplesMatchPlaybackRate: {}\n", .{self.General.SamplesMatchPlaybackRate});
        std.debug.print("\n", .{});

        // Print Metadata Section
        std.debug.print("[Metadata]\n", .{});
        std.debug.print("  Title: {s}\n", .{self.Metadata.Title});
        std.debug.print("  TitleUnicode: {s}\n", .{self.Metadata.TitleUnicode});
        std.debug.print("  Artist: {s}\n", .{self.Metadata.Artist});
        std.debug.print("  ArtistUnicode: {s}\n", .{self.Metadata.ArtistUnicode});
        std.debug.print("  Creator: {s}\n", .{self.Metadata.Creator});
        std.debug.print("  Version: {s}\n", .{self.Metadata.Version});
        std.debug.print("  Source: {s}\n", .{self.Metadata.Source});
        std.debug.print("  Tags: {s}\n", .{self.Metadata.Tags});
        std.debug.print("  BeatmapID: {d}\n", .{self.Metadata.BeatmapID});
        std.debug.print("  BeatmapSetID: {d}\n", .{self.Metadata.BeatmapSetID});
        std.debug.print("\n", .{});

        // Print Difficulty Section
        std.debug.print("[Difficulty]\n", .{});
        std.debug.print("  HPDrainRate: {d:.2}\n", .{self.Difficulty.HPDrainRate});
        std.debug.print("  CircleSize: {d:.2}\n", .{self.Difficulty.CircleSize});
        std.debug.print("  OverallDifficulty: {d:.2}\n", .{self.Difficulty.OverallDifficulty});
        std.debug.print("  ApproachRate: {d:.2}\n", .{self.Difficulty.ApproachRate});
        std.debug.print("  SliderMultiplier: {d:.2}\n", .{self.Difficulty.SliderMultiplier});
        std.debug.print("  SliderTickRate: {d:.2}\n", .{self.Difficulty.SliderTickRate});
        std.debug.print("\n", .{});

        // Print Timing Points
        std.debug.print("[TimingPoints] ({d} points)\n", .{self.TimingPoints.items.len});
        for (self.TimingPoints.items, 0..) |tp, i| {
            std.debug.print("  {d}: Time={d}, BeatLength={d:.2}, BeatMulitplier={d:.2} Meter={d}, SampleSet={}, Volume={d}, Inherited={}, IsKiai={}\n", .{ i, tp.Time, tp.BeatLength, tp.BeatMultiplier, tp.Meter, tp.SampleSet, tp.Volume, tp.Inherited, tp.IsKiai });
        }
        std.debug.print("\n", .{});

        // Print Hit Objects
        //std.debug.print("[HitObjects] ({d} objects)\n", .{self.HitObjects.items.len});
        //for (self.HitObjects.items, 0..) |obj, i| {
        //    std.debug.print("  {d}: ({d},{d}) Time={d}, HitSound={d}, NewCombo={}", .{ i, obj.X, obj.Y, obj.Time, obj.HitSoundSet.Bits, obj.IsNewCombo });
        //
        //    if (obj.HitCircle) |_| {
        //        std.debug.print(" [HitCircle]", .{});
        //    } else if (obj.HitSlider) |slider| {
        //        std.debug.print(" [Slider: Type={s}, Points={d}, Slides={d}, Length={d:.2}]", .{ @tagName(slider.Type), slider.CurvePoints.items.len, slider.Slides, slider.Length });
        //    } else if (obj.HitSpinner) |spinner| {
        //        std.debug.print(" [Spinner: EndTime={d}]", .{spinner.EndTime});
        //    }
        //    std.debug.print("\n", .{});
        //}
        //std.debug.print("\n", .{});

        // Print summary
        var hit_circles: u32 = 0;
        var sliders: u32 = 0;
        var spinners: u32 = 0;

        for (self.HitObjects.items) |obj| {
            if (obj.HitCircle != null) hit_circles += 1;
            if (obj.HitSlider != null) sliders += 1;
            if (obj.HitSpinner != null) spinners += 1;
        }

        std.debug.print("=== SUMMARY ===\n", .{});
        std.debug.print("Hit Circles: {d}\n", .{hit_circles});
        std.debug.print("Sliders: {d}\n", .{sliders});
        std.debug.print("Spinners: {d}\n", .{spinners});
        std.debug.print("Total Objects: {d}\n", .{self.HitObjects.items.len});
        std.debug.print("Timing Points: {d}\n", .{self.TimingPoints.items.len});
        std.debug.print("================\n", .{});
    }
};
