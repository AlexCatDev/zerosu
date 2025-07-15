const std = @import("std");
const c = @cImport({
    @cInclude("GLES2/gl2.h");
    @cInclude("stb_image.h");
});

pub fn _PrintGLError(name: []const u8) void {
    var glErr: c.GLenum = undefined;

    while (true) {
        glErr = c.glGetError();

        if (glErr == c.GL_NO_ERROR)
            return;

        std.debug.print("GLError {d} in [{s}]\n", .{ glErr, name });
    }
}

pub const Texture = struct {
    id: c.GLuint,
    target: c.GLenum,
    internalFormat: c.GLint,
    format: c.GLenum,
    pixelType: c.GLenum,

    width: i32,
    height: i32,
    channels: i32,

    pub fn Init(fileData: []const u8) !Texture {
        var texture = Texture{ .id = 0, .target = c.GL_TEXTURE_2D, .internalFormat = c.GL_RGBA, .format = c.GL_RGBA, .pixelType = c.GL_UNSIGNED_BYTE, .width = 0, .height = 0, .channels = 0 };

        c.glGenTextures(1, &texture.id);

        const pixels = c.stbi_load_from_memory(fileData.ptr, @intCast(fileData.len), &texture.width, &texture.height, &texture.channels, 4);

        if (pixels == null)
            return error.STBI_COULDNT_LOAD_FROM_MEMORY;

        std.debug.print("Loaded Texture[{d}] {d}x{d} // {d} bytes\n", .{ texture.id, texture.width, texture.height, fileData.len });

        texture.Bind(0);
        //PrintGLError("Texture bind");
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        //PrintGLError("Texture min and mag filter");
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        //PrintGLError("Texture Wrap S and T");
        c.glTexImage2D(texture.target, 0, texture.internalFormat, texture.width, texture.height, 0, texture.format, texture.pixelType, pixels);
        //PrintGLError("Texture upload");
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
        c.glGenerateMipmap(texture.target);

        //PrintGLError("Gen mipmap");
        return texture;
    }

    pub fn Init2(target: c.GLenum, width: i32, height: i32, internal_format: c.GLint, format: c.GLenum, pixel_type: c.GLenum) !Texture {
        var texture = Texture{ .id = 0, .target = target, .internalFormat = internal_format, .format = format, .pixelType = pixel_type, .width = width, .height = height, .channels = -1 };

        c.glGenTextures(1, &texture.id);
        texture.Bind(0);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        //PrintGLError("Texture min and mag filter");
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

        c.glTexImage2D(texture.target, 0, texture.internalFormat, texture.width, texture.height, 0, texture.format, texture.pixelType, @ptrFromInt(0));

        return texture;
    }

    pub fn Bind(self: *const Texture, slot: u8) void {
        if (self.id == 0)
            return;

        c.glActiveTexture(@intCast(c.GL_TEXTURE0 + slot));
        c.glBindTexture(self.target, self.id);
    }

    pub fn Deinit(self: *Texture) void {
        c.glDeleteTextures(1, &self.id);
        self.id = 0;
    }
};
