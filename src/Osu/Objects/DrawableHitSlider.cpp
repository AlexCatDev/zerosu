//
// Created by alex on 25/05/26.
//

#include "DrawableHitSlider.h"

#include "../../../include/osu!parser/Parser/Structures/Beatmap/HitObject.hpp"
#include "../../Scenes/PlayScene.h"
#include "../OsuSkin.h"
#include "CurveApproximator.h"
#include "Path.h"

DrawableHitSlider::DrawableHitSlider(Parser::HitObject& baseHitObject) : m_HitObject(baseHitObject) {
    if (baseHitObject.Time == baseHitObject.EndTime) {
        printf("Slider has no duration!!!!!!");
    }
    
    if (baseHitObject.SliderParameters.has_value()) {
        auto parameters = &baseHitObject.SliderParameters.value();


        printf("Parsing Slider: %c Control Points: %lu\n", parameters->Curve.Type, parameters->Curve.Points.size());

        std::vector<glm::vec2>* fullPath = new std::vector<glm::vec2>{};
        fullPath->reserve(64);

        std::vector<glm::vec2> buffer;

        auto compileSubPath = [&]() {
            if (buffer.size() > 0) {
                if (buffer.size()==2) {
                    fullPath->insert(fullPath->end(), buffer.begin(), buffer.end());
                }else {
                    //Parser::HitObject::SliderParams::SliderCurve::CurveType type = parameters->Curve.Type;
                    if (parameters->Curve.Type == Parser::HitObject::SliderParams::SliderCurve::CurveType::LINEAR) {
                        fullPath->insert(fullPath->end(), buffer.begin(), buffer.end());
                    }else if (parameters->Curve.Type == Parser::HitObject::SliderParams::SliderCurve::CurveType::CATMULL) {
                        std::vector<glm::vec2> catmullCurve = CurveApproximator::ApproximateCatmull(buffer);

                        fullPath->insert(fullPath->end(), catmullCurve.begin(), catmullCurve.end());
                    } else if (parameters->Curve.Type == Parser::HitObject::SliderParams::SliderCurve::CurveType::BEZIER) {
                        std::vector<glm::vec2> bezierCurve = CurveApproximator::ApproximateBezier(buffer);

                        fullPath->insert(fullPath->end(), bezierCurve.begin(), bezierCurve.end());
                    } else if (parameters->Curve.Type == Parser::HitObject::SliderParams::SliderCurve::CurveType::PERFECT) {
                        if (buffer.size() != 3) {
                            std::vector<glm::vec2> bezierCurve = CurveApproximator::ApproximateBezier(buffer);

                            fullPath->insert(fullPath->end(), bezierCurve.begin(), bezierCurve.end());
                        }
                        else {
                            std::vector<glm::vec2> arc = CurveApproximator::ApproximateCircularArc(buffer);

                            fullPath->insert(fullPath->end(), arc.begin(), arc.end());
                        }
                    }
                }
            }

            buffer.clear();
        };

        buffer.push_back(glm::vec2{baseHitObject.X, baseHitObject.Y});

        //Go through each slider control points
        for (int i = 0; i < parameters->Curve.Points.size(); i++)
        {
            auto now = parameters->Curve.Points[i];

            int index = std::min<int>(i + 1, parameters->Curve.Points.size() - 1);

            auto next = parameters->Curve.Points[index];

            buffer.emplace_back(glm::vec2(now.first, now.second));

            //If now and next are the same points, its a reset-path-point, or it might be the end of the list!
            //Either way we have to "compile" it.
            if (next == now)
                compileSubPath();
        }

        m_Path.SetPoints(fullPath);

    } else {
        printf("Slider has no parameters!!!!!!");
    }
}

void DrawableHitSlider::OnAdd(Drawable &parent) {

}

void DrawableHitSlider::OnRemove(Drawable &parent) {

}

void DrawableHitSlider::OnRender(Graphics &g) {
    constexpr float FADE_OUT_TIME = 241;

    float fadeInStart = m_HitObject.Time - PlayScene::GetPreemptTime();
    float fadeInEnd = m_HitObject.Time - PlayScene::GetPreemptTime() + PlayScene::GetFadeinTime();

    float alpha = Map(PlayScene::GetTrackTime(), fadeInStart, fadeInEnd, 0.0f, 1.0f);

    float fadeOut = Map(PlayScene::GetTrackTime(), m_HitObject.EndTime, m_HitObject.EndTime + FADE_OUT_TIME, 1.0f, 0.0f);
    fadeOut = std::min(fadeOut, 1.0f);

    float explodeScale = Map(PlayScene::GetTrackTime(), m_HitObject.Time, m_HitObject.Time + FADE_OUT_TIME, 1.0f, 1.4f);

    explodeScale = std::max(explodeScale, 1.0f);

    if (fadeOut <= 0.0f) {
        fadeOut = 0.0f;
        IsDead=true;
        return;
    }

    alpha = std::min(alpha, 1.0f)*fadeOut ;

    glm::vec4 color = glm::vec4{0.5f, 1.0f, std::sin(PlayScene::GetTrackTime() * 0.001f), alpha};
    glm::vec4 whiteColor = glm::vec4{1.0f, 1.0f, 1.0f, alpha};
    constexpr glm::vec4 TEX_RECT { 0,0, 1,1};

    glm::vec2 pos;

    PlayScene::MapToPlayfield(m_HitObject.X, m_HitObject.Y, pos);

    glm::vec2 size = glm::vec2{ PlayScene::RealCircleSize() } * explodeScale;
    glm::vec2 halfSize = size * 0.5f;

    g.DrawRectangle(pos - halfSize, size, color, OsuSkin::GetInstance().GetHitCircle().RealTexture, TEX_RECT);

    float approachCircleScale = Map(PlayScene::GetTrackTime(), fadeInStart, m_HitObject.Time, 4.0f, 1.0f);
    if (approachCircleScale >= 1.0f) {
        glm::vec2 approachSize = size * approachCircleScale;
        g.DrawRectangle(pos - approachSize * 0.5f, approachSize, color*0.9f, OsuSkin::GetInstance().GetApproachCircle().RealTexture, TEX_RECT);
    }

    float sliderProgress = Map(PlayScene::GetTrackTime(), m_HitObject.Time, m_HitObject.EndTime, 0.0f, 1.0f);
    sliderProgress = std::min(sliderProgress, 1.0f);

    for (auto a : *m_Path.m_Points) {
        PlayScene::MapToPlayfield(a.x, a.y, a);
        glm::vec2 s {10};
        g.DrawRectangle(a - s *0.5f, s, glm::vec4(1.0f,0.0f,0.0f, alpha), Texture::GetCircle(), TEX_RECT);
    }

    if (sliderProgress >= 0.0f) {
        auto ballPos = m_Path.CalculatePositionAtProgress(sliderProgress);
        PlayScene::MapToPlayfield(ballPos.x, ballPos.y, ballPos);

        g.DrawRectangle(ballPos - halfSize*0.5f, halfSize, color, Texture::GetCircle(), TEX_RECT);
    }

    g.DrawRectangle(pos - halfSize, size, whiteColor, OsuSkin::GetInstance().GetHitCircleOverlay().RealTexture, TEX_RECT);

}

void DrawableHitSlider::OnUpdate(float deltaTime) {

}

bool DrawableHitSlider::OnEvent(SDL_Event &e) {
    return false;
}

