//
// Created by alex on 25/05/26.
//

#ifndef DRAWABLEHITSLIDER_H
#define DRAWABLEHITSLIDER_H

#include "../../Drawable.h"
#include "../../../include/osu!parser/Parser/Structures/Beatmap/HitObject.hpp"
#include "Path.h"

class DrawableHitSlider : public Drawable {
private:
    Parser::HitObject& m_HitObject;
    Path m_Path;
public:
    DrawableHitSlider(Parser::HitObject& baseHitObject);

    void OnAdd(Drawable &parent) override;

    void OnRemove(Drawable &parent) override;

    void OnRender(Graphics &g) override;

    void OnUpdate(float deltaTime) override;

    bool OnEvent(SDL_Event &e) override;
};



#endif //DRAWABLEHITSLIDER_H
