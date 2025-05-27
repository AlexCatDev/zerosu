#pragma once

#include "../../../include/glm/glm.hpp"
#include "../../../include/glm/gtc/constants.hpp"
#include <vector>
#include <stack>
#include <algorithm>
#include <cmath>
#include <span>

namespace CurveApproximator {

    // Circular arc properties struct
    struct CircularArcProperties {
        bool is_valid = false;
        double theta_start = 0.0;
        double theta_range = 0.0;
        double direction = 1.0;
        float radius = 0.0f;
        glm::vec2 centre{0.0f};

        double theta_end() const { return theta_start + theta_range * direction; }
    };

    constexpr float BEZIER_TOLERANCE = 0.25f;
    constexpr float CIRCULAR_ARC_TOLERANCE = 0.1f;
    constexpr float PRECISION_EPSILON = 1e-6f;
    
    // Optimized precision check
    inline bool AlmostEquals(float a, float b, float epsilon = PRECISION_EPSILON) {
        return std::abs(a - b) < epsilon;
    }
    
    inline bool DefinitelyBigger(float a, float b, float epsilon = PRECISION_EPSILON) {
        return (a - b) > epsilon;
    }

    // Helper functions

    std::vector<double> CalculateBarycentricWeights(std::span<const glm::vec2> points) {
        const int n = static_cast<int>(points.size());
        std::vector<double> weights(n);

        for (int i = 0; i < n; i++) {
            weights[i] = 1.0;
            for (int j = 0; j < n; j++) {
                if (i != j) {
                    weights[i] *= (points[i].x - points[j].x);
                }
            }
            weights[i] = 1.0 / weights[i];
        }

        return weights;
    }

    double BarycentricLagrange(std::span<const glm::vec2> points, const std::vector<double>& weights, double time) {
        double numerator = 0.0;
        double denominator = 0.0;

        for (int i = 0; i < static_cast<int>(points.size()); i++) {
            // Handle exact match to avoid division by zero
            if (AlmostEquals(static_cast<float>(time), points[i].x)) {
                return points[i].y;
            }

            const double li = weights[i] / (time - points[i].x);
            numerator += li * points[i].y;
            denominator += li;
        }

        return numerator / denominator;
    }

    bool IsBezierFlatEnough(const std::vector<glm::vec2>& control_points) {
        constexpr float tolerance_squared = BEZIER_TOLERANCE * BEZIER_TOLERANCE * 4;

        for (size_t i = 1; i < control_points.size() - 1; i++) {
            const glm::vec2 second_derivative = control_points[i - 1] - 2.0f * control_points[i] + control_points[i + 1];
            if (glm::dot(second_derivative, second_derivative) > tolerance_squared) {
                return false;
            }
        }
        return true;
    }

    glm::vec2 CatmullFindPoint(const glm::vec2& v1, const glm::vec2& v2, const glm::vec2& v3, const glm::vec2& v4, float t) {
        const float t2 = t * t;
        const float t3 = t * t2;

        // Optimized Catmull-Rom calculation
        const glm::vec2 a = 2.0f * v2;
        const glm::vec2 b = (-v1 + v3) * t;
        const glm::vec2 c = (2.0f * v1 - 5.0f * v2 + 4.0f * v3 - v4) * t2;
        const glm::vec2 d = (-v1 + 3.0f * v2 - 3.0f * v3 + v4) * t3;

        return 0.5f * (a + b + c + d);
    }


    void BezierSubdivide(const std::vector<glm::vec2>& control_points,
                        std::vector<glm::vec2>& left, std::vector<glm::vec2>& right,
                        std::vector<glm::vec2>& subdivision_buffer) {
        const int count = static_cast<int>(control_points.size());
        subdivision_buffer.assign(control_points.begin(), control_points.end());

        for (int i = 0; i < count; i++) {
            left[i] = subdivision_buffer[0];
            right[count - i - 1] = subdivision_buffer[count - i - 1];

            for (int j = 0; j < count - i - 1; j++) {
                subdivision_buffer[j] = (subdivision_buffer[j] + subdivision_buffer[j + 1]) * 0.5f;
            }
        }
    }

    CircularArcProperties GetCircularArcProperties(const std::vector<glm::vec2>& control_points) {
        if (control_points.size() < 3) return {};

        const glm::vec2 a = control_points[0];
        const glm::vec2 b = control_points[1];
        const glm::vec2 c = control_points[2];

        // Check for degenerate triangle
        const float determinant = (b.y - a.y) * (c.x - a.x) - (b.x - a.x) * (c.y - a.y);
        if (AlmostEquals(determinant, 0.0f)) {
            return {};
        }

        // Calculate circumcenter
        const float d = 2.0f * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
        const float a_sq = glm::dot(a, a);
        const float b_sq = glm::dot(b, b);
        const float c_sq = glm::dot(c, c);

        const glm::vec2 centre = glm::vec2(
            a_sq * (b.y - c.y) + b_sq * (c.y - a.y) + c_sq * (a.y - b.y),
            a_sq * (c.x - b.x) + b_sq * (a.x - c.x) + c_sq * (b.x - a.x)
        ) / d;

        const glm::vec2 da = a - centre;
        const glm::vec2 dc = c - centre;
        const float radius = glm::length(da);

        double theta_start = std::atan2(da.y, da.x);
        double theta_end = std::atan2(dc.y, dc.x);

        while (theta_end < theta_start) {
            theta_end += 2 * glm::pi<double>();
        }

        double direction = 1.0;
        double theta_range = theta_end - theta_start;

        // Determine direction
        const glm::vec2 ortho_ac = glm::vec2(c.y - a.y, a.x - c.x);
        if (glm::dot(ortho_ac, b - a) < 0) {
            direction = -1.0;
            theta_range = 2 * glm::pi<double>() - theta_range;
        }

        CircularArcProperties props;
        props.is_valid = true;
        props.theta_start = theta_start;
        props.theta_range = theta_range;
        props.direction = direction;
        props.radius = radius;
        props.centre = centre;
        return props;
    }

    void BezierApproximate(const std::vector<glm::vec2>& control_points, std::vector<glm::vec2>& output,
                      std::vector<glm::vec2>& subdivision_buffer1, std::vector<glm::vec2>& subdivision_buffer2) {
        const int count = static_cast<int>(control_points.size());

        BezierSubdivide(control_points, subdivision_buffer2, subdivision_buffer1, subdivision_buffer1);

        // Merge left and right arrays
        for (int i = 0; i < count - 1; ++i) {
            subdivision_buffer2[count + i] = subdivision_buffer1[i + 1];
        }

        output.push_back(control_points[0]);

        for (int i = 1; i < count - 1; ++i) {
            const int index = 2 * i;
            const glm::vec2 p = 0.25f * (subdivision_buffer2[index - 1] + 2.0f * subdivision_buffer2[index] + subdivision_buffer2[index + 1]);
            output.push_back(p);
        }
    }
    
    // Forward declarations
    std::vector<glm::vec2> ApproximateBezier(const std::vector<glm::vec2>& control_points);
    std::vector<glm::vec2> ApproximateBSpline(const std::vector<glm::vec2>& control_points, int p = 0);
    std::vector<glm::vec2> ApproximateCatmull(const std::vector<glm::vec2>& control_points, int detail = 50);
    std::vector<glm::vec2> ApproximateCircularArc(const std::vector<glm::vec2>& control_points);
    std::vector<glm::vec2> ApproximateLinear(const std::vector<glm::vec2>& control_points);
    std::vector<glm::vec2> ApproximateLagrangePolynomial(std::span<const glm::vec2> control_points);
    
    // No-allocation version of Catmull approximation
    void ApproximateCatmullNoAlloc(const std::vector<glm::vec2>& control_points, 
                                   std::vector<glm::vec2>& output, int detail = 50);
    
    // Bounding box calculation for circular arcs
    glm::vec4 CircularArcBoundingBox(const std::vector<glm::vec2>& control_points); // (min_x, min_y, max_x, max_y)
    
    // Implementation
    
    std::vector<glm::vec2> ApproximateBezier(const std::vector<glm::vec2>& control_points) {
        return ApproximateBSpline(control_points);
    }
    
    std::vector<glm::vec2> ApproximateBSpline(const std::vector<glm::vec2>& control_points, int p) {
        std::vector<glm::vec2> output;
        const int n = static_cast<int>(control_points.size()) - 1;
        
        if (n < 0) return output;
        
        std::stack<std::vector<glm::vec2>> to_flatten;
        std::vector<glm::vec2> points = control_points;
        
        if (p > 0 && p < n) {
            // B-spline subdivision
            for (int i = 0; i < n - p; i++) {
                std::vector<glm::vec2> sub_bezier(p + 1);
                sub_bezier[0] = points[i];
                
                // Boehm's algorithm for knot insertion
                for (int j = 0; j < p - 1; j++) {
                    sub_bezier[j + 1] = points[i + 1];
                    
                    for (int k = 1; k < p - j; k++) {
                        int l = std::min(k, n - p - i);
                        points[i + k] = (static_cast<float>(l) * points[i + k] + points[i + k + 1]) / static_cast<float>(l + 1);
                    }
                }
                
                sub_bezier[p] = points[i + 1];
                to_flatten.push(std::move(sub_bezier));
            }
            
            std::vector<glm::vec2> last_segment(points.begin() + (n - p), points.end());
            to_flatten.push(std::move(last_segment));
            
            // Reverse stack for correct order
            std::stack<std::vector<glm::vec2>> temp_stack;
            while (!to_flatten.empty()) {
                temp_stack.push(std::move(to_flatten.top()));
                to_flatten.pop();
            }
            to_flatten = std::move(temp_stack);
        } else {
            // Degenerate to single bezier
            p = n;
            to_flatten.push(points);
        }
        
        // Adaptive subdivision using stack
        std::vector<glm::vec2> subdivision_buffer1(p + 1);
        std::vector<glm::vec2> subdivision_buffer2(p * 2 + 1);
        
        while (!to_flatten.empty()) {
            auto parent = std::move(to_flatten.top());
            to_flatten.pop();
            
            if (IsBezierFlatEnough(parent)) {
                BezierApproximate(parent, output, subdivision_buffer1, subdivision_buffer2);
                continue;
            }
            
            // Subdivide
            std::vector<glm::vec2> left_child(p + 1);
            std::vector<glm::vec2> right_child(p + 1);
            BezierSubdivide(parent, left_child, right_child, subdivision_buffer1);
            
            to_flatten.push(std::move(right_child));
            to_flatten.push(std::move(left_child));
        }
        
        if (!control_points.empty()) {
            output.push_back(control_points.back());
        }
        
        return output;
    }
    
    std::vector<glm::vec2> ApproximateCatmull(const std::vector<glm::vec2>& control_points, int detail) {
        std::vector<glm::vec2> result;
        result.reserve((control_points.size() - 1) * detail * 2);
        
        for (size_t i = 0; i < control_points.size() - 1; i++) {
            const glm::vec2 v1 = i > 0 ? control_points[i - 1] : control_points[i];
            const glm::vec2 v2 = control_points[i];
            const glm::vec2 v3 = i < control_points.size() - 1 ? control_points[i + 1] : v2 + v2 - v1;
            const glm::vec2 v4 = i < control_points.size() - 2 ? control_points[i + 2] : v3 + v3 - v2;
            
            for (int c = 0; c < detail; c++) {
                const float t1 = static_cast<float>(c) / detail;
                const float t2 = static_cast<float>(c + 1) / detail;
                result.push_back(CatmullFindPoint(v1, v2, v3, v4, t1));
                result.push_back(CatmullFindPoint(v1, v2, v3, v4, t2));
            }
        }
        
        return result;
    }
    
    void ApproximateCatmullNoAlloc(const std::vector<glm::vec2>& control_points, 
                                   std::vector<glm::vec2>& output, int detail) {
        output.clear();
        output.reserve((control_points.size() - 1) * detail * 2);
        
        for (size_t i = 0; i < control_points.size() - 1; i++) {
            const glm::vec2 v1 = i > 0 ? control_points[i - 1] : control_points[i];
            const glm::vec2 v2 = control_points[i];
            const glm::vec2 v3 = i < control_points.size() - 1 ? control_points[i + 1] : v2 + v2 - v1;
            const glm::vec2 v4 = i < control_points.size() - 2 ? control_points[i + 2] : v3 + v3 - v2;
            
            for (int c = 0; c < detail; c++) {
                const float t1 = static_cast<float>(c) / detail;
                const float t2 = static_cast<float>(c + 1) / detail;
                output.push_back(CatmullFindPoint(v1, v2, v3, v4, t1));
                output.push_back(CatmullFindPoint(v1, v2, v3, v4, t2));
            }
        }
    }
    
    std::vector<glm::vec2> ApproximateCircularArc(const std::vector<glm::vec2>& control_points) {
        const auto props = GetCircularArcProperties(control_points);
        if (!props.is_valid) {
            return ApproximateBezier(control_points);
        }
        
        const int amount_points = 2 * props.radius <= CIRCULAR_ARC_TOLERANCE ? 2 :
            std::max(2, static_cast<int>(std::ceil(props.theta_range / 
                (2 * std::acos(1 - CIRCULAR_ARC_TOLERANCE / props.radius)))));
        
        std::vector<glm::vec2> output;
        output.reserve(amount_points);
        
        for (int i = 0; i < amount_points; ++i) {
            const double fract = static_cast<double>(i) / (amount_points - 1);
            const double theta = props.theta_start + props.direction * fract * props.theta_range;
            const glm::vec2 offset = glm::vec2(std::cos(theta), std::sin(theta)) * props.radius;
            output.push_back(props.centre + offset);
        }
        
        return output;
    }
    
    glm::vec4 CircularArcBoundingBox(const std::vector<glm::vec2>& control_points) {
        const auto props = GetCircularArcProperties(control_points);
        if (!props.is_valid) {
            return glm::vec4(0.0f); // Empty rectangle
        }
        
        std::vector<glm::vec2> points = {control_points[0], control_points[2]};
        
        constexpr double right_angle = glm::pi<double>() / 2.0;
        const double step = right_angle * props.direction;
        const double quotient = props.theta_start / right_angle;
        const double closest_right_angle = right_angle * 
            (props.direction > 0 ? std::ceil(quotient) : std::floor(quotient));
        
        // Check at most 4 quadrant points
        for (int i = 0; i < 4; ++i) {
            const double angle = closest_right_angle + step * i;
            
            if (DefinitelyBigger((angle - props.theta_end()) * props.direction, 0)) {
                break;
            }
            
            const glm::vec2 offset = glm::vec2(std::cos(angle), std::sin(angle)) * props.radius;
            points.push_back(props.centre + offset);
        }
        
        const auto [min_x_it, max_x_it] = std::minmax_element(points.begin(), points.end(),
            [](const glm::vec2& a, const glm::vec2& b) { return a.x < b.x; });
        const auto [min_y_it, max_y_it] = std::minmax_element(points.begin(), points.end(),
            [](const glm::vec2& a, const glm::vec2& b) { return a.y < b.y; });
        
        return glm::vec4(min_x_it->x, min_y_it->y, max_x_it->x, max_y_it->y);
    }
    
    std::vector<glm::vec2> ApproximateLinear(const std::vector<glm::vec2>& control_points) {
        return control_points; // Direct copy, let compiler optimize
    }
    
    std::vector<glm::vec2> ApproximateLagrangePolynomial(std::span<const glm::vec2> control_points) {
        constexpr int num_steps = 51;
        std::vector<glm::vec2> result;
        result.reserve(num_steps);
        
        const auto weights = CalculateBarycentricWeights(control_points);
        
        const auto [min_x_it, max_x_it] = std::minmax_element(control_points.begin(), control_points.end(),
            [](const glm::vec2& a, const glm::vec2& b) { return a.x < b.x; });
        
        const float dx = max_x_it->x - min_x_it->x;
        
        for (int i = 0; i < num_steps; i++) {
            const float x = min_x_it->x + dx / (num_steps - 1) * i;
            const float y = static_cast<float>(BarycentricLagrange(control_points, weights, x));
            result.emplace_back(x, y);
        }
        
        return result;
    }

}