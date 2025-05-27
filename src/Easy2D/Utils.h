#ifndef UTILS_H
#define UTILS_H
#include <random>

inline float GetRandomFloat(float min = 0.0f, float max = 1.0f) {

    static std::random_device rd;   // non-deterministic seed
    static std::mt19937 gen(rd());  // Mersenne Twister RNG

    std::uniform_real_distribution<float> dist(min, max);
    return dist(gen);
}
/*
inline float Map(float value, float in_min, float in_max, float out_min, float out_max) {
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}
*/

inline float Map(float value, float fromSource, float toSource, float fromTarget, float toTarget)
{
    return (value - fromSource) / (toSource - fromSource) * (toTarget - fromTarget) + fromTarget;
}

class ProfileObject {
    static inline std::unordered_map<const char*, double> s_Profiles;
    const char* m_Name;
    const std::chrono::high_resolution_clock::time_point m_StartTime;
public:
    ProfileObject(const char* name) : m_Name(name), m_StartTime(std::chrono::high_resolution_clock::now()) { }

    ~ProfileObject() {
        std::chrono::high_resolution_clock::time_point endTime = std::chrono::high_resolution_clock::now();

        std::chrono::duration<double> elapsed = endTime - m_StartTime;

        s_Profiles.try_emplace(m_Name, elapsed.count() * 1000.0);
        s_Profiles[m_Name] = elapsed.count() * 1000.0;
    }

    static const std::unordered_map<const char*, double>& GetProfiles() {
        return s_Profiles;
    }
};
#endif //UTILS_H
