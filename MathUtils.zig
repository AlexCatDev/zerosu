const zm = @import("zm");

pub const MathUtils = struct {
    pub inline fn Map(value: f32, fromSource: f32, toSource: f32, fromTarget: f32, toTarget: f32) f32 {
        return (value - fromSource) / (toSource - fromSource) * (toTarget - fromTarget) + fromTarget;
    }

    pub inline fn Oscillate01(value: f32) f32 {
        const t = @mod(value, 2.0); // Wrap every 2.0 units
        return if (t < 1.0) t else 2.0 - t;
    }
    //pub inline fn Map2(value: zm.Vec2f, fromSource: f32, toSource: f32, fromTarget: f32, toTarget: f32) f32 {
    //    return (value - fromSource) / (toSource - fromSource) * (toTarget - fromTarget) + fromTarget;
    //}
};
