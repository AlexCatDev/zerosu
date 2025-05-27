#pragma once

#include <vector>
#include "../../../include/glm/glm.hpp"
//#include "../../../include/glm/gtx/norm.hpp"

class Path {
public:
     std::vector<glm::vec2>* m_Points;
    float m_Length=0.0f;
    glm::vec4 m_BoundingBox;
public:
    Path() = default;

    void SetPoints(std::vector<glm::vec2>* points) {
        m_Points = points;

        m_Length = CalculateLength(*m_Points);

        m_BoundingBox = CalculateBoundingBox(*m_Points);
    }

    glm::vec2 CalculatePositionAtProgress(float progress) {
        return CalculatePositionAtLength(m_Length * progress);
    };

    //Thank you so much Raresica1234
    glm::vec2 CalculatePositionAtLength(float length)
    {
        if (length <= 0) {
            glm::vec2 begin = (*m_Points)[0];
            return begin;
        }

        if (length >= m_Length){
            glm::vec2 ending = (*m_Points)[m_Points->size()-1];
            return ending;
        }

        for (int i = 0; i < m_Points->size() - 1; i++)
        {
            float dist = glm::distance((*m_Points)[i], (*m_Points)[i + 1]);

            if (length - dist <= 0)
            {
                float blend = length / dist;

                return glm::mix((*m_Points)[i], (*m_Points)[i + 1], blend);
            }
            length -= dist;
        }
        //just return the last point, if we're over the length
        return (*m_Points)[m_Points->size()-1];
    }
private:
    static float CalculateLength(const std::vector<glm::vec2>& points)
    {
        float length = 0.0f;
        for (int i = 0; i < points.size() - 1; i++)
            length += glm::distance(points[i], points[i + 1]);

        return length;
    }

    static glm::vec4 CalculateBoundingBox(const std::vector<glm::vec2>& points) {
        if (points.size() == 0)
            return glm::vec4{ 0 };
        ;
        float xmin = std::numeric_limits<float>::max();
        float xmax = 0;
        float ymin = std::numeric_limits<float>::max();
        float ymax = 0;

        for (int i = 0; i < points.size(); i++)
        {
            glm::vec2 current = points[i];

            if (xmin > current.x)
                xmin = current.x;

            if (ymin > current.y)
                ymin = current.y;

            if (xmax < current.x)
                xmax = current.x;

            if (ymax < current.y)
                ymax = current.y;
        }

        return glm::vec4{ xmin, ymin, xmax, ymax };
    }
};
