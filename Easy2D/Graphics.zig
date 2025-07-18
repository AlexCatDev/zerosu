const std = @import("std");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("GLES2/gl2.h");
});

const Texture = @import("Texture.zig").Texture;
const PrimitiveBatcher = @import("PrimitiveBatcher.zig").PrimitiveBatcher(Vertex);
const VertexBuffer = @import("GLBuffer.zig").GLBuffer(Vertex);
const IndexBuffer = @import("GLBuffer.zig").GLBuffer(u16);

const Shader = @import("Shader.zig").Shader;

const zm = @import("zm");

const Vertex = packed struct {
    Position: zm.Vec2f,
    TexCoord: zm.Vec2f,
    Color: zm.Vec4f,
    TexID: f32,

    pub fn EnableVertexAttribs() void {
        //pos
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(0));

        //uv
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(8));

        //color
        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(2, 4, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(16));

        //tex id
        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(3, 1, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(32));
    }

    pub fn DisableVertexAttribs() void {
        c.glDisableVertexAttribArray(0);
        c.glDisableVertexAttribArray(1);
        c.glDisableVertexAttribArray(2);
        c.glDisableVertexAttribArray(3);
    }
};

const MAX_TEXTURES: usize = 4;

const DEFAULT_FRAGMENT_SHADER_SRC = @embedFile("../shaders/main.frag");
const DEFAULT_VERTEX_SHADER_SRC = @embedFile("../shaders/main.vert");

//const TextureHashMap = std.AutoHashMap(*const Texture, u8);
const TextureBindList = std.ArrayList(c_uint);

pub const Graphics = struct {
    m_PrimitiveBatcher: PrimitiveBatcher,
    m_VertexBuffer: VertexBuffer,
    m_IndexBuffer: IndexBuffer,
    m_Shader: Shader,

    m_TextureBindList: TextureBindList,

    ProjectionMatrix: zm.Mat4f = zm.Mat4f.identity(),
    Time: f32 = 0.0,

    pub fn Init() !Graphics {
        const graphics = Graphics{
            .m_PrimitiveBatcher = try PrimitiveBatcher.Init(40000, 60000),
            .m_VertexBuffer = try VertexBuffer.Init(c.GL_ARRAY_BUFFER),
            .m_IndexBuffer = try IndexBuffer.Init(c.GL_ELEMENT_ARRAY_BUFFER),

            .m_Shader = try Shader.Init(DEFAULT_VERTEX_SHADER_SRC, DEFAULT_FRAGMENT_SHADER_SRC),

            .m_TextureBindList = TextureBindList.init(std.heap.c_allocator),
        };

        return graphics;
    }

    inline fn getTextureSlot(self: *Graphics, tex: *const Texture) usize {
        for (self.m_TextureBindList.items, 0..) |handle, i| {
            if (tex.id == handle)
                return i;
        }

        if (self.m_TextureBindList.items.len == MAX_TEXTURES) {
            self.EndDraw();
        }
        const index = self.m_TextureBindList.items.len;

        self.m_TextureBindList.append(tex.id) catch unreachable;
        return index;
    }

    pub inline fn DrawRectangleCentered(self: *Graphics, pos: zm.Vec2f, size: zm.Vec2f, color: zm.Vec4f, texture: *const Texture, textureRect: zm.Vec4f) void {
        const newPos = pos - size * zm.Vec2f{ 0.5, 0.5 };

        self.DrawRectangle(newPos, size, color, texture, textureRect);
    }

    pub inline fn DrawQuad(self: *Graphics, v1: zm.Vec2f, v2: zm.Vec2f, v3: zm.Vec2f, v4: zm.Vec2f, color: zm.Vec4f, texture: *const Texture, texture_rect: zm.Vec4f) void {
        const slot = self.getTextureSlot(texture);

        var quad = self.m_PrimitiveBatcher.GetQuad();

        //glm::vec2 rotationOrigin = position;

        const texIDFloat: f32 = @floatFromInt(slot);

        quad[0] = Vertex{
            .Position = v1,
            .TexCoord = .{ texture_rect[0], texture_rect[1] },
            .Color = color,
            .TexID = texIDFloat,
        };

        quad[1].Position = v2;
        //quad[1].Rotation = rotation;
        quad[1].TexID = texIDFloat;
        quad[1].Color = color;
        //quad[1].RotationOrigin = rotationOrigin;
        quad[1].TexCoord = .{ texture_rect[0] + texture_rect[2], texture_rect[1] };

        quad[2].Position = v3;
        //quad[2].Rotation = rotation;
        quad[2].TexID = texIDFloat;
        quad[2].Color = color;
        //quad[2].RotationOrigin = rotationOrigin;
        quad[2].TexCoord = .{ texture_rect[0] + texture_rect[2], texture_rect[1] + texture_rect[3] };

        quad[3].Position = v4;
        //quad[3].Rotation = rotation;
        quad[3].TexID = texIDFloat;
        quad[3].Color = color;
        //quad[3].RotationOrigin = rotationOrigin;
        quad[3].TexCoord = .{ texture_rect[0], texture_rect[1] + texture_rect[3] };
    }

    pub inline fn DrawRect(self: *Graphics, bounds: zm.Vec4f, color: zm.Vec4f, texture: *const Texture, texture_rect: zm.Vec4f) void {
        const slot = self.getTextureSlot(texture);

        var quad = self.m_PrimitiveBatcher.GetQuad();

        //glm::vec2 rotationOrigin = position;

        const texIDFloat: f32 = @floatFromInt(slot);

        quad[0] = Vertex{
            .Position = .{ bounds[0], bounds[1] },
            .TexCoord = .{ texture_rect[0], texture_rect[1] },
            .Color = color,
            .TexID = texIDFloat,
        };

        quad[1].Position = .{ bounds[2], bounds[1] };
        //quad[1].Rotation = rotation;
        quad[1].TexID = texIDFloat;
        quad[1].Color = color;
        //quad[1].RotationOrigin = rotationOrigin;
        quad[1].TexCoord = .{ texture_rect[0] + texture_rect[2], texture_rect[1] };

        quad[2].Position = .{ bounds[2], bounds[3] };
        //quad[2].Rotation = rotation;
        quad[2].TexID = texIDFloat;
        quad[2].Color = color;
        //quad[2].RotationOrigin = rotationOrigin;
        quad[2].TexCoord = .{ texture_rect[0] + texture_rect[2], texture_rect[1] + texture_rect[3] };

        quad[3].Position = .{ bounds[0], bounds[3] };
        //quad[3].Rotation = rotation;
        quad[3].TexID = texIDFloat;
        quad[3].Color = color;
        //quad[3].RotationOrigin = rotationOrigin;
        quad[3].TexCoord = .{ texture_rect[0], texture_rect[1] + texture_rect[3] };
    }

    pub inline fn DrawRectangle(self: *Graphics, pos: zm.Vec2f, size: zm.Vec2f, color: zm.Vec4f, texture: *const Texture, textureRect: zm.Vec4f) void {
        const slot = self.getTextureSlot(texture);

        var quad = self.m_PrimitiveBatcher.GetQuad();

        //glm::vec2 rotationOrigin = position;

        const texIDFloat: f32 = @floatFromInt(slot);

        quad[0] = Vertex{
            .Position = pos,
            .TexCoord = .{ textureRect[0], textureRect[1] },
            .Color = color,
            .TexID = texIDFloat,
        };

        quad[1].Position = .{ pos[0] + size[0], pos[1] };
        //quad[1].Rotation = rotation;
        quad[1].TexID = texIDFloat;
        quad[1].Color = color;
        //quad[1].RotationOrigin = rotationOrigin;
        quad[1].TexCoord = .{ textureRect[0] + textureRect[2], textureRect[1] };

        quad[2].Position = pos + size;
        //quad[2].Rotation = rotation;
        quad[2].TexID = texIDFloat;
        quad[2].Color = color;
        //quad[2].RotationOrigin = rotationOrigin;
        quad[2].TexCoord = .{ textureRect[0] + textureRect[2], textureRect[1] + textureRect[3] };

        quad[3].Position = .{ pos[0], pos[1] + size[1] };
        //quad[3].Rotation = rotation;
        quad[3].TexID = texIDFloat;
        quad[3].Color = color;
        //quad[3].RotationOrigin = rotationOrigin;
        quad[3].TexCoord = .{ textureRect[0], textureRect[1] + textureRect[3] };
    }

    pub fn EndDraw(self: *Graphics) void {
        //Bind Textures

        for (0..self.m_TextureBindList.items.len) |i| {
            c.glActiveTexture(@intCast(c.GL_TEXTURE0 + i));
            c.glBindTexture(c.GL_TEXTURE_2D, self.m_TextureBindList.items[i]);
        }

        //PrintGLError("bind textures");
        //Enable Shader
        self.m_Shader.Use();
        //PrintGLError("bind shader");
        //Set uniforms
        self.m_Shader.SetMat4f("u_Projection", &self.ProjectionMatrix);
        //PrintGLError("set projection");
        self.m_Shader.SetI32("u_tex0", 0);
        //PrintGLError("tex0");
        self.m_Shader.SetI32("u_tex1", 1);
        //PrintGLError("tex1");
        self.m_Shader.SetI32("u_tex2", 2);
        //PrintGLError("tex2");
        self.m_Shader.SetI32("u_tex3", 3);

        const BorderColorOuter: zm.Vec3f = .{ 0.5, 0.5, 0.5 };
        const BorderColorInner: zm.Vec3f = .{ 0.5, 0.5, 0.5 };

        const TrackColorInner: zm.Vec3f = .{ 0.2, 0.2, 0.2 };
        const TrackColorOuter: zm.Vec3f = .{ 0.0, 0.0, 0.0 };

        const ShadowColor: zm.Vec4f = .{ 0.0, 0.0, 0.0, 0.5 };

        const BorderWidth: f32 = 1.0;
        self.m_Shader.SetFloat("u_BorderWidth", BorderWidth);

        self.m_Shader.SetVec3f("u_BorderColorOuter", BorderColorOuter);
        self.m_Shader.SetVec3f("u_BorderColorInner", BorderColorInner);

        self.m_Shader.SetVec3f("u_TrackColorOuter", TrackColorOuter);
        self.m_Shader.SetVec3f("u_TrackColorInner", TrackColorInner);

        self.m_Shader.SetVec4f("u_ShadowColor", ShadowColor);

        self.m_Shader.SetFloat("u_Time", self.Time);
        //PrintGLError("tex3");
        //const tmpTexBuf: [16]u8 = undefined;
        //for (0..MAX_TEXTURES) |i| {
        //    const fmtedString = try std.fmt.bufPrint(tmpTexBuf, "u_tex{d}", .{i});
        //    self.m_Shader.SetI32(fmtedString, i);
        //}

        //Get upload data..
        const uploadData = self.m_PrimitiveBatcher.GetUploadData();

        self.m_IndexBuffer.OrphanUpload(uploadData.IndexSlice, c.GL_DYNAMIC_DRAW);
        //PrintGLError("index buffer upload");
        self.m_VertexBuffer.OrphanUpload(uploadData.VertexSlice, c.GL_DYNAMIC_DRAW);
        //PrintGLError("vertex buffer upload");
        Vertex.EnableVertexAttribs();
        //PrintGLError("enable vertex attribs");
        c.glDrawElements(c.GL_TRIANGLES, @intCast(uploadData.IndexSlice.len), c.GL_UNSIGNED_SHORT, null);
        //PrintGLError("draw elements");
        Vertex.DisableVertexAttribs();
        //PrintGLError("disable vertex attribs");
        self.m_TextureBindList.clearRetainingCapacity();
        self.m_PrimitiveBatcher.ResetWritePosition();
    }
};
