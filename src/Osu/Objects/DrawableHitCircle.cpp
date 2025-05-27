//
// Created by alex on 25/05/22.
//

#include "DrawableHitCircle.h"

#include "../OsuSkin.h"
#include "../../Easy2D/Utils.h"
#include "../../Scenes/PlayScene.h"

DrawableHitCircle::DrawableHitCircle(Parser::HitObject& baseHitObject) : baseHitObject(baseHitObject) {

}

void DrawableHitCircle::OnAdd(Drawable &parent) {

}

void DrawableHitCircle::OnRemove() {

}

void DrawableHitCircle::OnRender(Graphics &g) {
    constexpr float FADE_OUT_TIME = 240;

    float fadeInStart = baseHitObject.Time - PlayScene::GetPreemptTime();
    float fadeInEnd = baseHitObject.Time - PlayScene::GetPreemptTime() + PlayScene::GetFadeinTime();

    float alpha = Map(PlayScene::GetTrackTime(), fadeInStart, fadeInEnd, 0.0f, 1.0f);

    float fadeOut = Map(PlayScene::GetTrackTime(), baseHitObject.Time, baseHitObject.Time + FADE_OUT_TIME, 1.0f, 0.0f);
    fadeOut = std::min(fadeOut, 1.0f);

    float explodeScale = Map(PlayScene::GetTrackTime(), baseHitObject.Time, baseHitObject.Time + FADE_OUT_TIME, 1.0f, 1.4f);

    explodeScale = std::max(explodeScale, 1.0f);

    if (fadeOut <= 0.0f) {
        explodeScale = 0.0f;
        IsDead=true;
        return;
    }

    alpha = std::min(alpha, 1.0f)*fadeOut ;

    glm::vec4 color = glm::vec4{std::sin(PlayScene::GetTrackTime() * 0.001f), 0.5f, 1.0f, alpha};
    glm::vec4 whiteColor = glm::vec4{1.0f, 1.0f, 1.0f, alpha};
    constexpr glm::vec4 TEX_RECT { 0,0, 1,1};

    glm::vec2 pos;

    PlayScene::MapToPlayfield(baseHitObject.X, baseHitObject.Y, pos);

    glm::vec2 size = glm::vec2{ PlayScene::RealCircleSize() } * explodeScale;
    glm::vec2 halfSize = size * 0.5f;

    g.DrawRectangle(pos - halfSize, size, color, OsuSkin::GetInstance().GetHitCircle().RealTexture, TEX_RECT);

    float approachCircleScale = Map(PlayScene::GetTrackTime(), fadeInStart, baseHitObject.Time, 4.0f, 1.0f);
    if (approachCircleScale >= 1.0f) {
        glm::vec2 approachSize = size * approachCircleScale;
        g.DrawRectangle(pos - approachSize * 0.5f, approachSize, color*0.9f, OsuSkin::GetInstance().GetApproachCircle().RealTexture, TEX_RECT);
    }

    g.DrawRectangle(pos - halfSize, size, whiteColor, OsuSkin::GetInstance().GetHitCircleOverlay().RealTexture, TEX_RECT);

}

void DrawableHitCircle::OnUpdate(float deltaTime) {

}

bool DrawableHitCircle::OnEvent(SDL_Event &e) {
    return false;
}
