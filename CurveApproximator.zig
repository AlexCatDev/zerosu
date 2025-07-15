const std = @import("std");
const zm = @import("zm");
const math = std.math;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const CurveApproximator = struct {
    // Circular arc properties struct
    pub const CircularArcProperties = struct {
        is_valid: bool = false,
        theta_start: f64 = 0.0,
        theta_range: f64 = 0.0,
        direction: f64 = 1.0,
        radius: f32 = 0.0,
        centre: zm.Vec2f = zm.Vec2f{ 0.0, 0.0 },

        pub fn theta_end(self: CircularArcProperties) f64 {
            return self.theta_start + self.theta_range * self.direction;
        }
    };

    pub const BEZIER_TOLERANCE: f32 = 0.25;
    pub const CIRCULAR_ARC_TOLERANCE: f32 = 0.1;
    pub const PRECISION_EPSILON: f32 = 1e-6;

    // Optimized precision check
    pub fn almostEquals(a: f32, b: f32, epsilon: f32) bool {
        return @abs(a - b) < epsilon;
    }

    pub fn almostEqualsDefault(a: f32, b: f32) bool {
        return almostEquals(a, b, PRECISION_EPSILON);
    }

    pub fn definitelyBigger(a: f32, b: f32, epsilon: f32) bool {
        return (a - b) > epsilon;
    }

    pub fn definitelyBiggerDefault(a: f32, b: f32) bool {
        return definitelyBigger(a, b, PRECISION_EPSILON);
    }

    // Helper functions
    pub fn calculateBarycentricWeights(allocator: Allocator, points: []const zm.Vec2f) ![]f64 {
        const n = points.len;
        var weights = try allocator.alloc(f64, n);

        for (0..n) |i| {
            weights[i] = 1.0;
            for (0..n) |j| {
                if (i != j) {
                    weights[i] *= (points[i][0] - points[j][0]);
                }
            }
            weights[i] = 1.0 / weights[i];
        }

        return weights;
    }

    pub fn barycentricLagrange(points: []const zm.Vec2f, weights: []const f64, time: f64) f64 {
        var numerator: f64 = 0.0;
        var denominator: f64 = 0.0;

        for (0..points.len) |i| {
            // Handle exact match to avoid division by zero
            if (almostEqualsDefault(@floatCast(time), points[i][0])) {
                return points[i][1];
            }

            const li = weights[i] / (time - points[i][0]);
            numerator += li * points[i][1];
            denominator += li;
        }

        return numerator / denominator;
    }

    pub fn isBezierFlatEnough(control_points: []const zm.Vec2f) bool {
        const tolerance_squared = BEZIER_TOLERANCE * BEZIER_TOLERANCE * 4;
        //std.debug.print("isBezierFlatEnough control_points.len: {d}\n", .{control_points.len});

        for (1..control_points.len - 1) |i| {
            const two = zm.Vec2f{ 2.0, 2.0 };
            const second_derivative = control_points[i - 1] - two * control_points[i] + control_points[i + 1];
            if (zm.vec.dot(second_derivative, second_derivative) > tolerance_squared) {
                return false;
            }
        }
        return true;
    }

    pub fn catmullFindPoint(v1: zm.Vec2f, v2: zm.Vec2f, v3: zm.Vec2f, v4: zm.Vec2f, t: f32) zm.Vec2f {
        const t2 = t * t;
        const t3 = t * t2;

        const half = zm.Vec2f{ 0.5, 0.5 };
        const two = zm.Vec2f{ 2.0, 2.0 };
        const three = zm.Vec2f{ 3.0, 3.0 };
        const four = zm.Vec2f{ 4.0, 4.0 };
        const five = zm.Vec2f{ 5.0, 5.0 };

        // Optimized Catmull-Rom calculation
        const a = two * v2;
        const b = (-v1 + v3) * zm.Vec2f{ t, t };
        const c = (two * v1 - five * v2 + four * v3 - v4) * zm.Vec2f{ t2, t2 };
        const d = (-v1 + three * v2 - three * v3 + v4) * zm.Vec2f{ t3, t3 };

        return half * (a + b + c + d);
    }

    pub fn bezierSubdivide(
        control_points: []const zm.Vec2f,
        left: []zm.Vec2f,
        right: []zm.Vec2f,
        subdivision_buffer: []zm.Vec2f,
    ) void {
        const count = control_points.len;
        @memcpy(subdivision_buffer[0..count], control_points);

        for (0..count) |i| {
            left[i] = subdivision_buffer[0];
            right[count - i - 1] = subdivision_buffer[count - i - 1];

            for (0..count - i - 1) |j| {
                subdivision_buffer[j] = (subdivision_buffer[j] + subdivision_buffer[j + 1]) * zm.Vec2f{ 0.5, 0.5 };
            }
        }
    }

    pub fn getCircularArcProperties(control_points: []const zm.Vec2f) CircularArcProperties {
        if (control_points.len < 3) return CircularArcProperties{};

        const a = control_points[0];
        const b = control_points[1];
        const c = control_points[2];

        // Check for degenerate triangle
        const determinant = (b[1] - a[1]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[1] - a[1]);
        if (almostEqualsDefault(determinant, 0.0)) {
            return CircularArcProperties{};
        }

        // Calculate circumcenter
        const d = 2.0 * (a[0] * (b[1] - c[1]) + b[0] * (c[1] - a[1]) + c[0] * (a[1] - b[1]));

        const a_sq = zm.vec.dot(a, a);
        const b_sq = zm.vec.dot(b, b);
        const c_sq = zm.vec.dot(c, c);

        const centre = zm.Vec2f{
            a_sq * (b[1] - c[1]) + b_sq * (c[1] - a[1]) + c_sq * (a[1] - b[1]),
            a_sq * (c[0] - b[0]) + b_sq * (a[0] - c[0]) + c_sq * (b[0] - a[0]),
        } / zm.Vec2f{ d, d };

        const da = a - centre;
        const dc = c - centre;

        const radius = zm.vec.len(da);

        const theta_start = math.atan2(da[1], da[0]);
        var theta_end = math.atan2(dc[1], dc[0]);

        while (theta_end < theta_start) {
            theta_end += 2 * math.pi;
        }

        var direction: f64 = 1.0;
        var theta_range = theta_end - theta_start;

        // Determine direction
        const ortho_ac = zm.Vec2f{ c[1] - a[1], a[0] - c[0] };
        if (zm.vec.dot(ortho_ac, b - a) < 0) {
            direction = -1.0;
            theta_range = 2 * math.pi - theta_range;
        }

        return CircularArcProperties{
            .is_valid = true,
            .theta_start = theta_start,
            .theta_range = theta_range,
            .direction = direction,
            .radius = radius,
            .centre = centre,
        };
    }

    pub fn bezierApproximate(
        control_points: []const zm.Vec2f,
        output: *ArrayList(zm.Vec2f),
        subdivision_buffer1: []zm.Vec2f,
        subdivision_buffer2: []zm.Vec2f,
    ) !void {
        const count = control_points.len;

        bezierSubdivide(control_points, subdivision_buffer2, subdivision_buffer1, subdivision_buffer1);

        // Merge left and right arrays
        for (0..count - 1) |i| {
            subdivision_buffer2[count + i] = subdivision_buffer1[i + 1];
        }

        try output.append(control_points[0]);

        for (1..count - 1) |i| {
            const index = 2 * i;
            const two = zm.Vec2f{ 2.0, 2.0 };
            const quarter = zm.Vec2f{ 0.25, 0.25 };
            const p = quarter * (subdivision_buffer2[index - 1] + two * subdivision_buffer2[index] + subdivision_buffer2[index + 1]);
            try output.append(p);
        }
    }

    // Main approximation functions
    pub fn approximateBezier(allocator: Allocator, control_points: []const zm.Vec2f) ![]zm.Vec2f {
        return approximateBSpline(allocator, control_points, 0);
    }

    pub fn approximateBSpline(allocator: Allocator, control_points: []const zm.Vec2f, p: i32) ![]zm.Vec2f {
        var output = ArrayList(zm.Vec2f).init(allocator);
        defer output.deinit();

        const n = @as(i32, @intCast(control_points.len)) - 1;

        if (n < 0) return try output.toOwnedSlice();

        const Stack = ArrayList([]zm.Vec2f);
        var to_flatten = Stack.init(allocator);
        defer {
            // Clean up any remaining slices in the stack
            while (to_flatten.items.len > 0) {
                const item = to_flatten.pop().?;
                allocator.free(item);
            }
            to_flatten.deinit();
        }

        var points = try allocator.dupe(zm.Vec2f, control_points);
        defer allocator.free(points);

        var actual_p = p;

        if (p > 0 and p < n) {
            // B-spline subdivision
            for (0..@intCast(n - p)) |i| {
                var sub_bezier = try allocator.alloc(zm.Vec2f, @intCast(p + 1));
                sub_bezier[0] = points[i];

                // Boehm's algorithm for knot insertion
                for (0..@intCast(p - 1)) |j| {
                    sub_bezier[j + 1] = points[i + 1];

                    for (1..@intCast(p - @as(i32, @intCast(j)))) |k| {
                        const l = @min(k, @as(usize, @intCast(n - p)) - i);
                        //const l_float: f32 = @floatFromInt(l);

                        const l_float = zm.Vec2f{ @floatFromInt(l), @floatFromInt(l) };
                        const l_float_plus_one = zm.Vec2f{ l_float[0] + 1.0, l_float[1] + 1.0 };
                        points[i + k] = (l_float * points[i + k] + points[i + k + 1]) / l_float_plus_one;
                    }
                }

                sub_bezier[@intCast(p)] = points[i + 1];
                try to_flatten.append(sub_bezier);
            }

            const last_segment = try allocator.dupe(zm.Vec2f, points[@intCast(n - p)..]);
            try to_flatten.append(last_segment);

            // Reverse stack for correct order
            var temp_stack = Stack.init(allocator);
            defer temp_stack.deinit();
            while (to_flatten.items.len > 0) {
                const item = to_flatten.pop().?;
                try temp_stack.append(item);
            }
            to_flatten = temp_stack;
        } else {
            // Degenerate to single bezier
            actual_p = n;
            const points_copy = try allocator.dupe(zm.Vec2f, points);
            try to_flatten.append(points_copy);
        }

        // Adaptive subdivision using stack
        const subdivision_buffer1 = try allocator.alloc(zm.Vec2f, @intCast(actual_p + 1));
        defer allocator.free(subdivision_buffer1);
        const subdivision_buffer2 = try allocator.alloc(zm.Vec2f, @intCast(actual_p * 2 + 1));
        defer allocator.free(subdivision_buffer2);

        while (to_flatten.items.len > 0) {
            const parent = to_flatten.pop().?;
            defer allocator.free(parent);

            if (isBezierFlatEnough(parent)) {
                try bezierApproximate(parent, &output, subdivision_buffer1, subdivision_buffer2);
                continue;
            }

            // Subdivide
            const left_child = try allocator.alloc(zm.Vec2f, @intCast(actual_p + 1));
            const right_child = try allocator.alloc(zm.Vec2f, @intCast(actual_p + 1));
            bezierSubdivide(parent, left_child, right_child, subdivision_buffer1);

            try to_flatten.append(right_child);
            try to_flatten.append(left_child);
        }

        if (control_points.len > 0) {
            try output.append(control_points[control_points.len - 1]);
        }

        return try output.toOwnedSlice();
    }

    pub fn approximateCatmull(allocator: Allocator, control_points: []const zm.Vec2f, detail: i32) ![]zm.Vec2f {
        var result = ArrayList(zm.Vec2f).init(allocator);
        defer result.deinit();

        try result.ensureTotalCapacity((control_points.len - 1) * @as(usize, @intCast(detail)) * 2);

        for (0..control_points.len - 1) |i| {
            const v1 = if (i > 0) control_points[i - 1] else control_points[i];
            const v2 = control_points[i];
            const v3 = if (i < control_points.len - 1) control_points[i + 1] else v2 + v2 - v1;
            const v4 = if (i < control_points.len - 2) control_points[i + 2] else v3 + v3 - v2;

            for (0..@intCast(detail)) |c| {
                const t1: f32 = @floatFromInt(c);
                const t2: f32 = @floatFromInt(c + 1);
                const detail_float: f32 = @floatFromInt(detail);
                try result.append(catmullFindPoint(v1, v2, v3, v4, t1 / detail_float));
                try result.append(catmullFindPoint(v1, v2, v3, v4, t2 / detail_float));
            }
        }

        return try result.toOwnedSlice();
    }

    pub fn approximateCatmullNoAlloc(
        control_points: []const zm.Vec2f,
        output: *ArrayList(zm.Vec2f),
        detail: i32,
    ) !void {
        output.clearRetainingCapacity();
        try output.ensureTotalCapacity((control_points.len - 1) * @as(usize, @intCast(detail)) * 2);

        for (0..control_points.len - 1) |i| {
            const v1 = if (i > 0) control_points[i - 1] else control_points[i];
            const v2 = control_points[i];
            const v3 = if (i < control_points.len - 1) control_points[i + 1] else v2 + v2 - v1;
            const v4 = if (i < control_points.len - 2) control_points[i + 2] else v3 + v3 - v2;

            for (0..@intCast(detail)) |c| {
                const t1: f32 = @floatFromInt(c);
                const t2: f32 = @floatFromInt(c + 1);
                const detail_float: f32 = @floatFromInt(detail);
                try output.append(catmullFindPoint(v1, v2, v3, v4, t1 / detail_float));
                try output.append(catmullFindPoint(v1, v2, v3, v4, t2 / detail_float));
            }
        }
    }

    pub fn approximateCircularArc(allocator: Allocator, control_points: []const zm.Vec2f) ![]zm.Vec2f {
        const props = getCircularArcProperties(control_points);
        if (!props.is_valid) {
            return approximateBezier(allocator, control_points);
        }

        const amount_points = if (2 * props.radius <= CIRCULAR_ARC_TOLERANCE)
            2
        else
            @max(2, @as(i32, @intFromFloat(@ceil(props.theta_range / (2 * math.acos(1 - CIRCULAR_ARC_TOLERANCE / props.radius))))));

        var output = ArrayList(zm.Vec2f).init(allocator);
        defer output.deinit();
        try output.ensureTotalCapacity(@intCast(amount_points));

        for (0..@intCast(amount_points)) |i| {
            const fract: f64 = @floatFromInt(i);
            const amount_points_f64: f64 = @floatFromInt(amount_points - 1);
            const theta = props.theta_start + props.direction * (fract / amount_points_f64) * props.theta_range;
            const offset = zm.Vec2f{ @floatCast(math.cos(theta)), @floatCast(math.sin(theta)) } * zm.Vec2f{ props.radius, props.radius };
            try output.append(props.centre + offset);
        }

        return try output.toOwnedSlice();
    }

    pub fn circularArcBoundingBox(control_points: []const zm.Vec2f) zm.Vec4f {
        const props = getCircularArcProperties(control_points);
        if (!props.is_valid) {
            return zm.Vec4f{ 0.0, 0.0, 0.0, 0.0 }; // Empty rectangle
        }

        var points = [_]zm.Vec2f{ control_points[0], control_points[2] };
        var point_count: usize = 2;

        const right_angle = math.pi / 2.0;
        const step = right_angle * props.direction;
        const quotient = props.theta_start / right_angle;
        const closest_right_angle = right_angle * if (props.direction > 0) @ceil(quotient) else @floor(quotient);

        // Check at most 4 quadrant points
        for (0..4) |i| {
            const angle = closest_right_angle + step * @as(f64, @floatFromInt(i));

            if (definitelyBiggerDefault(@floatCast((angle - props.theta_end()) * props.direction), 0)) {
                break;
            }

            if (point_count < points.len) {
                const offset = zm.Vec2f{ @floatCast(math.cos(angle)), @floatCast(math.sin(angle)) } * zm.Vec2f{ props.radius, props.radius };
                points[point_count] = props.centre + offset;
                point_count += 1;
            }
        }

        const used_points = points[0..point_count];
        var min_x = used_points[0][0];
        var max_x = used_points[0][0];
        var min_y = used_points[0][1];
        var max_y = used_points[0][1];

        for (used_points[1..]) |point| {
            min_x = @min(min_x, point[0]);
            max_x = @max(max_x, point[0]);
            min_y = @min(min_y, point[1]);
            max_y = @max(max_y, point[1]);
        }

        return zm.Vec4f{ min_x, min_y, max_x, max_y };
    }

    pub fn approximateLinear(allocator: Allocator, control_points: []const zm.Vec2f) ![]zm.Vec2f {
        return try allocator.dupe(zm.Vec2f, control_points);
    }

    pub fn approximateLagrangePolynomial(allocator: Allocator, control_points: []const zm.Vec2f) ![]zm.Vec2f {
        const num_steps = 51;
        var result = ArrayList(zm.Vec2f).init(allocator);
        defer result.deinit();
        try result.ensureTotalCapacity(num_steps);

        const weights = try calculateBarycentricWeights(allocator, control_points);
        defer allocator.free(weights);

        var min_x = control_points[0][0];
        var max_x = control_points[0][0];
        for (control_points[1..]) |point| {
            min_x = @min(min_x, point[0]);
            max_x = @max(max_x, point[0]);
        }

        const dx = max_x - min_x;

        for (0..num_steps) |i| {
            const x = min_x + dx / (num_steps - 1) * @as(f32, @floatFromInt(i));
            const y: f32 = @floatCast(barycentricLagrange(control_points, weights, x));
            try result.append(zm.Vec2f{ x, y });
        }

        return try result.toOwnedSlice();
    }
};
