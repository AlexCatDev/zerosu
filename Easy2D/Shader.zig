const std = @import("std");
const c = @cImport({
    @cInclude("GLES2/gl2.h");
});
const zm = @import("zm");

pub const Shader = struct {
    program: c.GLuint,
    //[*:0]const u8
    pub fn Init(vertex_src: []const u8, fragment_src: []const u8) !Shader {
        const vertex_shader = try compileShader(c.GL_VERTEX_SHADER, sanitizeString(vertex_src));
        const fragment_shader = try compileShader(c.GL_FRAGMENT_SHADER, sanitizeString(fragment_src));

        const program = c.glCreateProgram();
        c.glAttachShader(program, vertex_shader);
        c.glAttachShader(program, fragment_shader);
        c.glLinkProgram(program);

        var status: c.GLint = 0;
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &status);
        if (status == 0) {
            var log: [512]u8 = undefined;
            var logLength: c_int = undefined;
            c.glGetProgramInfoLog(program, 512, &logLength, &log[0]);
            std.debug.print("Shader link error: {s}\n", .{log[0..@intCast(logLength)]});
            return error.ProgramLinkFailed;
        }

        c.glDeleteShader(vertex_shader);
        c.glDeleteShader(fragment_shader);

        //PrintGLError("Make Shader");

        return Shader{ .program = program };
    }

    pub fn SetVec2f(self: *Shader, name: [*c]const u8, vec: zm.Vec2f) void {
        c.glUniform2f(findUniform(self, name), vec[0], vec[1]);
    }

    pub fn SetVec3f(self: *Shader, name: [*c]const u8, vec: zm.Vec3f) void {
        c.glUniform3f(findUniform(self, name), vec[0], vec[1], vec[2]);
    }

    pub fn SetVec4f(self: *Shader, name: [*c]const u8, vec: zm.Vec4f) void {
        c.glUniform4f(findUniform(self, name), vec[0], vec[1], vec[2], vec[3]);
    }

    pub fn SetFloat(self: *Shader, name: [*c]const u8, value: f32) void {
        c.glUniform1f(findUniform(self, name), value);
    }

    pub fn SetI32(self: *Shader, name: [*c]const u8, value: i32) void {
        c.glUniform1i(findUniform(self, name), value);
    }

    pub fn SetMat4f(self: *Shader, name: [*c]const u8, mat4f: *const zm.Mat4f) void {
        //self.Use();
        //transpose true doesnt work on rpi fyi
        c.glUniformMatrix4fv(findUniform(self, name), 1, c.GL_FALSE, @ptrCast(mat4f));
    }

    fn findUniform(self: *Shader, name: [*c]const u8) c.GLint {
        const location = c.glGetUniformLocation(self.program, name);

        if (location == -1) {
            //std.debug.print("Uniform '{s}' not found", .{name});
        }

        return location;
    }

    pub fn Use(self: *Shader) void {
        c.glUseProgram(self.program);
    }

    pub fn Deinit(self: *Shader) void {
        c.glDeleteProgram(self.program);
        self.program = 0;
    }

    pub fn sanitizeString(input: []const u8) []const u8 {
        //check if input starts with UTF-8 BOM (0xEF,0xBB,0xBF)
        if (input.len >= 3 and input[0] == 0xEF and input[1] == 0xBB and input[2] == 0xBF) {
            //slice without BOM prefix
            return input[3..];
        }
        return input;
    }

    fn compileShader(kind: c.GLenum, src: []const u8) !c.GLuint {
        const shader = c.glCreateShader(kind);
        c.glShaderSource(shader, 1, @ptrCast(@alignCast(&src.ptr)), @ptrCast(&src.len));
        c.glCompileShader(shader);

        var status: c.GLint = 0;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            var log: [512]u8 = undefined;
            var logLength: c_int = undefined;
            c.glGetShaderInfoLog(shader, 512, &logLength, &log[0]);
            std.debug.print("[{s}] Shader compile error: {s}\n: ", .{ shaderTypeToString(kind), log[0..@intCast(logLength)] });
            std.debug.print("\r\t{s}\n", .{src});
            return error.ShaderCompileFailed;
        }

        const shaderTypeName = shaderTypeToString(kind);

        std.debug.print("[{s}]Shader compile success!\n", .{shaderTypeName});

        return shader;
    }

    fn shaderTypeToString(kind: c.GLenum) []const u8 {
        return switch (kind) {
            c.GL_VERTEX_SHADER => "VERTEX_SHADER",
            c.GL_FRAGMENT_SHADER => "FRAGMENT_SHADER",
            else => "??UNKNOWN_SHADER??",
        };
    }
};
