const std = @import("std");

pub fn PrimitiveBatcher(comptime T: type) type {
    return struct {
        OutOfSpaceCallback: ?*const fn (*PrimitiveBatcher(T)) void = null,
        vertexBuffer: []T,
        indexBuffer: []u16,

        vertexWriteIndex: u16 = 0,
        indexWriteIndex: u16 = 0,

        pub fn Init(vertexCnt: u16, indexCnt: u16) !PrimitiveBatcher(T) {
            //Primitive batchers are almost always meant to live for the lifetime of the application, not sure what mem allocator to use
            const batcher = PrimitiveBatcher(T){
                .vertexBuffer = try std.heap.c_allocator.alloc(T, vertexCnt),
                .indexBuffer = try std.heap.c_allocator.alloc(u16, indexCnt),
            };
            return batcher;
        }

        pub inline fn ResetWritePosition(self: *PrimitiveBatcher(T)) void {
            self.vertexWriteIndex = 0;
            self.indexWriteIndex = 0;
        }

        pub inline fn GetIndexCount(self: *const PrimitiveBatcher(T)) u16 {
            return self.indexWriteIndex;
        }

        pub inline fn GetVertexCount(self: *const PrimitiveBatcher(T)) u16 {
            return self.vertexWriteIndex;
        }

        pub inline fn GetUploadData(self: *PrimitiveBatcher(T)) struct { VertexSlice: []const T, IndexSlice: []const u16 } {
            return .{ .VertexSlice = self.vertexBuffer[0..self.vertexWriteIndex], .IndexSlice = self.indexBuffer[0..self.indexWriteIndex] };
        }

        pub inline fn GetTriangle(self: *PrimitiveBatcher(T)) []T {
            self.checkCapacity(3, 3);

            self.indexBuffer[self.indexWriteIndex + 0] = self.vertexWriteIndex + 0;
            self.indexBuffer[self.indexWriteIndex + 1] = self.vertexWriteIndex + 1;
            self.indexBuffer[self.indexWriteIndex + 2] = self.vertexWriteIndex + 2;

            self.indexWriteIndex += 3;
            self.vertexWriteIndex += 3;

            return self.vertexBuffer[self.vertexWriteIndex - 3 .. self.vertexWriteIndex];
        }

        pub inline fn GetQuad(self: *PrimitiveBatcher(T)) []T {
            self.checkCapacity(4, 6);

            self.indexBuffer[self.indexWriteIndex + 0] = self.vertexWriteIndex + 0;
            self.indexBuffer[self.indexWriteIndex + 1] = self.vertexWriteIndex + 1;
            self.indexBuffer[self.indexWriteIndex + 2] = self.vertexWriteIndex + 2;

            self.indexBuffer[self.indexWriteIndex + 3] = self.vertexWriteIndex + 0;
            self.indexBuffer[self.indexWriteIndex + 4] = self.vertexWriteIndex + 2;
            self.indexBuffer[self.indexWriteIndex + 5] = self.vertexWriteIndex + 3;

            self.indexWriteIndex += 6;
            self.vertexWriteIndex += 4;

            return self.vertexBuffer[self.vertexWriteIndex - 4 .. self.vertexWriteIndex];
        }

        pub inline fn GetTriangleStrip(self: *PrimitiveBatcher(T), pointCount: u16) ![]T {
            if (pointCount < 3)
                return error.InvalidPointCount;

            self.checkCapacity(pointCount, (pointCount - 2) * 3);

            for (0..pointCount - 2) |idx| {
                const i: u16 = @intCast(idx);
                // use i

                self.indexBuffer[self.indexWriteIndex + 0] = self.vertexWriteIndex + i;
                self.indexBuffer[self.indexWriteIndex + 1] = self.vertexWriteIndex + i + 1;
                self.indexBuffer[self.indexWriteIndex + 2] = self.vertexWriteIndex + i + 2;
                self.indexWriteIndex += 3;
            }

            self.vertexWriteIndex += pointCount;
            return self.vertexBuffer[self.vertexWriteIndex - pointCount .. self.vertexWriteIndex];
        }

        pub inline fn GetTriangleFan(self: *PrimitiveBatcher(T), pointCount: u16) ![]T {
            if (pointCount < 3)
                return error.InvalidPointCount;

            self.checkCapacity(pointCount, (pointCount - 2) * 3);

            for (0..pointCount - 1) |idx| {
                const i: u16 = @intCast(idx);
                // use i

                self.indexBuffer[self.indexWriteIndex + 0] = self.vertexWriteIndex;
                self.indexBuffer[self.indexWriteIndex + 1] = self.vertexWriteIndex + i;
                self.indexBuffer[self.indexWriteIndex + 2] = self.vertexWriteIndex + i + 1;
                self.indexWriteIndex += 3;
            }

            self.vertexWriteIndex += pointCount;
            return self.vertexBuffer[self.vertexWriteIndex - pointCount .. self.vertexWriteIndex];
        }

        inline fn checkCapacity(self: *PrimitiveBatcher(T), vCount: u32, iCount: u32) void {
            if (self.vertexWriteIndex + vCount > self.vertexBuffer.len) {
                if (self.OutOfSpaceCallback) |oomCallback| {
                    oomCallback(self);
                }

                if (self.vertexWriteIndex + vCount > self.vertexBuffer.len)
                    std.debug.panic("Unhandled VertexBuffer capacity overflow {d} > {d}", .{ (self.vertexWriteIndex + vCount), self.vertexBuffer.len });
            }

            if (self.indexWriteIndex + iCount > self.indexBuffer.len) {
                if (self.OutOfSpaceCallback) |oomCallback| {
                    oomCallback(self);
                }

                if (self.indexWriteIndex + iCount > self.indexBuffer.len)
                    std.debug.panic("Unhandled IndexBuffer capacity overflow {d} > {d}", .{ (self.indexWriteIndex + iCount), self.indexBuffer.len });
            }
        }
    };
}
