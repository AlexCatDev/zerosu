const std = @import("std");

pub const ButtonMaskStruct = packed struct {
    M1: u1,
    M2: u1,
    K1: u1,
    K2: u1,
    Smoke: u1,
};

pub const ReplayFrame = struct {
    Time: u64,
    Delta: u64,
    X: f32,
    Y: f32,
    ///Bitwise combination of keys/mouse buttons pressed (M1 = 1, M2 = 2, K1 = 4, K2 = 8, Smoke = 16) (K1 is always used with M1; K2 is always used with M2: 1+4=5; 2+8=10)
    ButtonMask: u32,
};

pub const ReplayInfo = struct {
    GameMode: u8,
    GameVersion: u32,
    BeatmapMD5Hash: []const u8,
    PlayerName: []const u8,
    ReplayMD5Hash: []const u8,
    Count300: u16,
    Count100: u16,
    Count50: u16,
    CountGeki: u16,
    CountKatu: u16,
    CountMiss: u16,
    TotalScore: u32,
    HighestCombo: u16,
    FullCombo: bool,
    Mods: u32,
    Lifebar: []const u8,
    Timestamp: u64,
    OnlineScoreID: u64,
};

pub const Replay = struct {
    ReplayFrames: std.ArrayList(ReplayFrame),
    ReplayInfo: ReplayInfo,
    m_Allocator: std.mem.Allocator,

    pub fn FromFile(allocator: std.mem.Allocator, file_path: []const u8) !Replay {

        //const allocator = std.heap.c_allocator;
        const file = try std.fs.openFileAbsolute(file_path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(allocator, 1024 * 1000);
        defer allocator.free(data);

        var read_pos: usize = 0;

        const game_mode = readu8(data, &read_pos);

        const game_version = readu32(data, &read_pos); //std.mem.readInt(i32, @ptrCast(&data[read_pos]), .little);

        const md5_hash = try readString(data, &read_pos);
        const player_name = try readString(data, &read_pos);
        const replay_md5 = try readString(data, &read_pos);

        const count_300 = readu16(data, &read_pos);
        const count_100 = readu16(data, &read_pos);
        const count_50 = readu16(data, &read_pos);

        const count_geki = readu16(data, &read_pos);
        const count_katu = readu16(data, &read_pos);

        const count_miss = readu16(data, &read_pos);

        const total_score = readu32(data, &read_pos);
        const highest_combo = readu16(data, &read_pos);

        const full_combo = readu8(data, &read_pos);

        const mods = readu32(data, &read_pos);

        const lifebar = try readString(data, &read_pos);

        const timestamp = readu64(data, &read_pos);

        const replay_data_len: usize = @intCast(readu32(data, &read_pos));
        //this is really dangerous lol

        if (replay_data_len + read_pos >= data.len)
            return error.InvalidReplayLengthBufferOverflow;

        const replay_data = data[read_pos .. read_pos + replay_data_len];
        read_pos += replay_data_len;

        var reader = std.io.fixedBufferStream(replay_data);
        var lzma_stream = try std.compress.lzma.decompress(allocator, reader.reader());

        const replay_data_decom = try lzma_stream.reader().readAllAlloc(allocator, 5_000_000);

        defer lzma_stream.deinit();
        defer allocator.free(replay_data_decom);

        const replay_frames = parseReplayData(allocator, replay_data_decom);
        //_ = replay_data_decom;

        const online_score_id = readu64(data, &read_pos);

        //Only in the data if mods has target practice
        //const additional_mod_info: f64 = std.mem.bytesToValue(f64, &data[read_pos]);

        //std.debug.print("GameMode: {d} GameVersion: {d}\nMD5 Hash: {s}\nPlayer Name: {s}\nReplay MD5: {s}\nHit Counts: 300: {d}, 100: {d}, 50: {d}\nGeki: {d}, Katu: {d}, Miss: {d}\nScore: {d}, Combo: {d}\nMods: {d}\nLifebar: {s}\nTimestamp: {d}\nReplay Data Length: {d}\nReplay Data: {s}\nOnline ID: {d}\nFull combo: {d}\n", .{
        //    game_mode,
        //    game_version,
        //    md5_hash,
        //    player_name,
        //    replay_md5,
        //    count_300,
        //    count_100,
        //    count_50,
        //    count_geki,
        //    count_katu,
        //    count_miss,
        //    total_score,
        //    highest_combo,
        //    mods,
        //    lifebar,
        //    timestamp,
        //    replay_data_len,
        //    replay_data,
        //    online_score_id,
        //    //additional_mod_info,
        //    full_combo,
        //});

        return .{
            .m_Allocator = allocator,
            .ReplayFrames = replay_frames,
            .ReplayInfo = .{
                .GameMode = game_mode,
                .GameVersion = game_version,
                .BeatmapMD5Hash = allocator.dupe(u8, md5_hash) catch unreachable,
                .PlayerName = allocator.dupe(u8, player_name) catch unreachable,
                .ReplayMD5Hash = allocator.dupe(u8, replay_md5) catch unreachable,
                .Count300 = count_300,
                .Count100 = count_100,
                .Count50 = count_50,
                .CountGeki = count_geki,
                .CountKatu = count_katu,
                .CountMiss = count_miss,
                .TotalScore = total_score,
                .HighestCombo = highest_combo,
                .FullCombo = full_combo == 1,
                .Mods = mods,
                .Lifebar = allocator.dupe(u8, lifebar) catch unreachable,
                .Timestamp = timestamp,
                .OnlineScoreID = online_score_id,
            },
        };
    }

    pub fn Deinit(self: *Replay) void {
        self.ReplayFrames.deinit();
        self.m_Allocator.free(self.ReplayInfo.BeatmapMD5Hash);
        self.m_Allocator.free(self.ReplayInfo.PlayerName);
        self.m_Allocator.free(self.ReplayInfo.ReplayMD5Hash);
        self.m_Allocator.free(self.ReplayInfo.Lifebar);
    }

    fn parseReplayData(allocator: std.mem.Allocator, data: []const u8) std.ArrayList(ReplayFrame) {
        var replay_frames = std.ArrayList(ReplayFrame).initCapacity(allocator, 10) catch unreachable;

        var frames = std.mem.splitScalar(u8, data, ',');

        var total_time: u64 = 0;

        while (frames.next()) |next_frame| {
            var frame_data = std.mem.splitScalar(u8, next_frame, '|');

            var time: u64 = 0;
            var x: f32 = 0.0;
            var y: f32 = 0.0;
            var button_mask: u32 = 0;

            if (frame_data.next()) |time_str| {
                time = std.fmt.parseInt(u64, time_str, 10) catch 0;

                //ignore negative frametimes for that rng seed thing
                if (time < 0)
                    continue;

                total_time += time;
            }

            if (frame_data.next()) |x_str| {
                x = std.fmt.parseFloat(f32, x_str) catch 0.0;
            }

            if (frame_data.next()) |y_str| {
                y = std.fmt.parseFloat(f32, y_str) catch 0.0;
            }

            if (frame_data.next()) |button_mask_str| {
                button_mask = std.fmt.parseInt(u32, button_mask_str, 10) catch 0;
            }

            replay_frames.append(.{
                .Time = total_time,
                .Delta = time,
                .X = x,
                .Y = y,
                .ButtonMask = button_mask,
            }) catch unreachable;
            //_ = frame_data;

            //std.debug.print("Frame: {s}\n", .{next_frame});
        }

        return replay_frames;
    }

    fn readu8(buffer: []const u8, read_pos: *usize) u8 {
        const value = buffer[read_pos.*];
        read_pos.* += 1;
        return value;
    }

    fn readu16(buffer: []const u8, read_pos: *usize) u16 {
        const value: u16 = std.mem.readInt(u16, @ptrCast(&buffer[read_pos.*]), .little);
        read_pos.* += 2;

        return value;
    }

    fn readu32(buffer: []const u8, read_pos: *usize) u32 {
        const value: u32 = std.mem.readInt(u32, @ptrCast(&buffer[read_pos.*]), .little);
        read_pos.* += 4;

        return value;
    }

    fn readu64(buffer: []const u8, read_pos: *usize) u64 {
        const value: u64 = std.mem.readInt(u64, @ptrCast(&buffer[read_pos.*]), .little);
        read_pos.* += 8;

        return value;
    }

    fn readString(buffer: []const u8, read_pos: *usize) ![]const u8 {
        const status = buffer[read_pos.*];
        read_pos.* += 1;

        if (status == 0)
            return "";

        const str_len = try readVarInt(buffer, read_pos);
        if (str_len >= (read_pos.* + str_len))
            return error.InvalidStrLenBufferOverflow;

        const str = buffer[read_pos.*..(read_pos.* + str_len)];
        read_pos.* += str_len;
        return str;
    }

    fn readVarInt(buffer: []const u8, read_pos: *usize) !usize {
        var result: usize = 0;
        var shift: u6 = 0;

        var i = read_pos.*;
        defer read_pos.* = i + 1;
        while (i < buffer.len) : (i += 1) {
            const byte = buffer[i];
            const payload = byte & 0x7F;
            result |= (@as(usize, payload) << shift);

            if ((byte & 0x80) == 0) {
                //return result;
                break;
            }

            shift += 7;
            if (shift >= @bitSizeOf(usize)) {
                return error.ULEB128Overflow;
            }
        }

        return result;
    }

    //pub fn FromData() Replay {}
};
