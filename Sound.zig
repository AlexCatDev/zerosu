const std = @import("std");

const Bass = @cImport({
    @cInclude("bass.h");
});

pub const Sound = struct {
    pub fn InitBass(window: ?*anyopaque) void {
        if (Bass.BASS_Init(-1, 44100, Bass.BASS_DEVICE_LATENCY | Bass.BASS_DEVICE_STEREO, window, null) == 0) {
            const bassErr = Bass.BASS_ErrorGetCode();

            std.debug.print("Couldn't init bass: {d}\n", .{bassErr});
        } else {
            const bassVer = Bass.BASS_GetVersion();
            var info: Bass.BASS_INFO = undefined;

            _ = Bass.BASS_GetInfo(&info);
            std.debug.print("Bass loaded: {d} Latency: {d} Speakers: {d}\n", .{ bassVer, info.latency, info.speakers });
        }
    }

    Stream: Bass.HSTREAM,

    //なんかデュプリケートした

    pub fn FromFile(file: []const u8) Sound {
        const stream = Bass.BASS_StreamCreateFile(Bass.FALSE, &file[0], 0, 0, Bass.BASS_STREAM_PRESCAN | Bass.BASS_SAMPLE_FLOAT);

        const bassErr = Bass.BASS_ErrorGetCode();

        if (bassErr != Bass.BASS_OK) {
            std.debug.print("[StreamCreateFile BassError: {d}]\n", .{bassErr});
        }

        const sound = Sound{ .Stream = stream };
        return sound;
    }

    pub fn FromData(data: []const u8) Sound {
        const stream = Bass.BASS_StreamCreateFile(Bass.TRUE, &data[0], 0, data.len, Bass.BASS_STREAM_PRESCAN | Bass.BASS_SAMPLE_FLOAT);

        const bassErr = Bass.BASS_ErrorGetCode();

        if (bassErr != Bass.BASS_OK) {
            std.debug.print("[StreamCreateFile BassError: {d}]\n", .{bassErr});
        }

        const sound = Sound{ .Stream = stream };
        return sound;
    }

    pub fn GetPlaybackPositionInSeconds(self: *const Sound) f64 {
        const byte_pos = Bass.BASS_ChannelGetPosition(self.Stream, Bass.BASS_POS_BYTE);
        return Bass.BASS_ChannelBytes2Seconds(self.Stream, byte_pos);
    }

    pub fn SetPlaybackPositionSecs(self: *Sound, secs: f64) void {
        const byte_pos = Bass.BASS_ChannelSeconds2Bytes(self.Stream, secs);
        _ = Bass.BASS_ChannelSetPosition(self.Stream, byte_pos, Bass.BASS_POS_BYTE);
    }

    pub fn SetVolume(self: *Sound, volume: f32) void {
        _ = Bass.BASS_ChannelSetAttribute(self.Stream, Bass.BASS_FX_VOLUME, volume);
    }

    pub fn Pause(self: *Sound) void {
        _ = Bass.BASS_ChannelPause(self.Stream);
    }

    pub fn TogglePlay(self: *Sound) void {
        if (Bass.BASS_ChannelIsActive(self.Stream) == Bass.BASS_ACTIVE_PAUSED) {
            self.Play(false);
        } else {
            self.Pause();
        }
    }

    pub fn Play(self: *Sound, restart: bool) void {
        _ = Bass.BASS_ChannelPlay(self.Stream, @intFromBool(restart));
    }

    pub fn GetFrequency(self: *Sound) f32 {
        const freq: f32 = 0.0;
        _ = Bass.BASS_ChannelGetAttribute(self.Stream, Bass.BASS_ATTRIB_FREQ, &freq);
        return freq;
    }

    pub fn SetFrequency(self: *Sound, value: f32) void {
        Bass.BASS_ChannelSetAttribute(self.Stream, Bass.BASS_ATTRIB_FREQ, value);
    }

    pub fn Deinit(self: *Sound) void {
        _ = Bass.BASS_StreamFree(self.Stream);
    }
};
