const std = @import("std");
const c = @import("../CImports.zig").c;

pub fn GLBuffer(comptime T: type) type {
    return struct {
        id: c.GLuint,
        target: c.GLenum,

        pub fn Init(target: c.GLenum) !GLBuffer(T) {
            var buffer = GLBuffer(T){ .id = 0, .target = target };
            c.glGenBuffers(1, &buffer.id);
            Use(&buffer);
            if (buffer.id == 0) return error.BufferGenFailed;

            return buffer;
        }

        pub fn Upload(self: *GLBuffer(T), data: []const T, usage: c.GLenum) void {
            if (self.id == 0)
                return;

            c.glBindBuffer(self.target, self.id);

            const sizeBytes: c_long = @intCast(@sizeOf(T) * data.len);

            c.glBufferData(self.target, sizeBytes, data.ptr, usage);
        }

        pub fn OrphanUpload(self: *GLBuffer(T), data: []const T, usage: c.GLenum) void {
            if (self.id == 0)
                return;

            c.glBindBuffer(self.target, self.id);
            //std.debug.print("Buffer id: {d} buffer target: {d}\n", .{ self.id, self.target });
            //PrintGLError("Buffer Bind");
            const sizeBytes: c_long = @intCast(@sizeOf(T) * data.len);

            //Orphan
            c.glBufferData(self.target, sizeBytes, null, usage);
            //PrintGLError("Buffer Orphan");
            //Update
            c.glBufferSubData(self.target, 0, sizeBytes, data.ptr);
            //PrintGLError("Buffer Subdata");
        }

        pub fn Deinit(self: *GLBuffer(T)) void {
            if (self.id == 0)
                return;

            c.glDeleteBuffers(1, &self.id);
            self.id = 0;
        }

        pub fn Use(self: *GLBuffer(T)) void {
            if (self.id == 0)
                return;

            c.glBindBuffer(self.target, self.id);
        }
    };
}
