const std = @import("std");
const Graphics = @import("../Easy2D/Graphics.zig").Graphics;
const c = @import("../CImports.zig").c;
const Profiler = @import("../Profiler.zig").Profiler;

pub const OnDrawFn = *const fn (self: *anyopaque, g: *Graphics) void;
pub const OnUpdateFn = *const fn (self: *anyopaque, delta: f32) void;
pub const OnAddFn = *const fn (self: *anyopaque, manager: *DrawableManager) void;
pub const OnEventFn = *const fn (self: *anyopaque, event: *const c.SDL_Event) bool;

pub const DrawableData = struct {
    BaseObjectPtr: *anyopaque,
    BaseObjectTypeID: u64,
    OnDrawFn: OnDrawFn,
    OnUpdateFn: OnUpdateFn,
    OnEventFn: OnEventFn,
    OnAddFn: OnAddFn,
    Layer: *i32,
    IsDead: *bool,

    pub fn GetTypeID(comptime T: type) u64 {
        const name = @typeName(T);
        const seed: u64 = 0x72745678_abddef69;
        return std.hash.Wyhash.hash(seed, name);
    }
};

pub const DrawableManager = struct {
    m_GameObjects: std.ArrayList(DrawableData),
    m_ObjectsPending: std.ArrayList(DrawableData),
    m_HashedObjects: std.AutoHashMap(DrawableData, void),

    pub fn Init() DrawableManager {
        const manager = DrawableManager{
            .m_GameObjects = std.ArrayList(DrawableData).init(std.heap.c_allocator),
            .m_ObjectsPending = std.ArrayList(DrawableData).init(std.heap.c_allocator),
            .m_HashedObjects = std.AutoHashMap(DrawableData, void).init(std.heap.c_allocator),
        };
        return manager;
    }

    pub fn Draw(self: *DrawableManager, g: *Graphics) void {
        const items = self.m_GameObjects.items;

        for (0..items.len) |i| {
            items[i].OnDrawFn(items[i].BaseObjectPtr, g);
        }
    }

    pub fn OnEvent(self: *DrawableManager, event: *const c.SDL_Event) bool {
        const objs = self.m_GameObjects.items;
        for (0..objs.len) |i| {
            const ateEvent = objs[i].OnEventFn(objs[i].BaseObjectPtr, event);
            if (ateEvent)
                return true;
        }

        return false;
    }

    fn sortFunction(_: void, left: DrawableData, right: DrawableData) bool {
        return left.Layer.* <= right.Layer.*;
    }

    pub fn GetAllOfType(self: *DrawableManager, T: type, callback: fn (obj: *T) bool) void {
        for (0..self.m_GameObjects.items.len) |i| {
            if (self.m_GameObjects.items[i].BaseObjectTypeID == DrawableData.GetTypeID(T)) {
                const complete = callback(@ptrCast(@alignCast(self.m_GameObjects.items[i].BaseObjectPtr)));
                if (complete)
                    return;
            }
        }
    }

    pub fn Update(self: *DrawableManager, delta: f32) void {
        var requireSorting = false;

        const objs = self.m_GameObjects.items;

        //Update all gameobjects, skipping dead ones, and checking what needs to be sorted
        var prevLayer: i32 = std.math.minInt(i32);

        for (0..objs.len) |i| {
            //TODO: Skip if dead and just remove here?
            if (objs[i].IsDead.*)
                continue;

            objs[i].OnUpdateFn(objs[i].BaseObjectPtr, delta);

            const layer = objs[i].Layer.*;

            if (layer < prevLayer) {
                requireSorting = true;
            }

            prevLayer = layer;
        }

        //Remove all dead gameobjects
        var i: usize = objs.len;
        while (i > 0) {
            i -= 1;
            if (objs[i].IsDead.*) {
                const removedObject = self.m_GameObjects.swapRemove(i);
                requireSorting = true;
                _ = self.m_HashedObjects.remove(removedObject);
            }
        }

        //Add Pending gameobjects
        if (self.m_ObjectsPending.items.len > 0) {
            _ = self.m_GameObjects.appendSlice(self.m_ObjectsPending.items) catch |err| {
                std.debug.print("Error adding pending game objects {} ", .{err});
            };
            //std.debug.print("Added {d} pending game objects.\n", .{self.m_ObjectsPending.items.len});
            self.m_ObjectsPending.clearRetainingCapacity();
            requireSorting = true;
        }

        //Sort if needed
        if (requireSorting) {

            //std.sort.argMax(GameObjData, self.m_GameObjects.items, context: anytype, comptime lessThan: fn(context:@TypeOf(context), lhs:T, rhs:T)bool)
            //std.mem.sort(GameObjData, self.m_GameObjects.items, context: anytype, comptime lessThanFn: fn(@TypeOf(context), lhs:T, rhs:T)bool)
            std.sort.block(DrawableData, self.m_GameObjects.items, {}, sortFunction);

            //std.debug.print("Sorted {d} Objects\n", .{self.m_GameObjects.items.len});
        }
    }

    pub fn Add(self: *DrawableManager, objData: DrawableData) !void {
        //Add to temp list
        if (self.m_HashedObjects.contains(objData)) {
            return error.DuplicateGameObject;
        }

        try self.m_HashedObjects.put(objData, {});

        objData.IsDead.* = false;
        const newItem = try self.m_ObjectsPending.addOne();
        newItem.* = objData;
    }
};
