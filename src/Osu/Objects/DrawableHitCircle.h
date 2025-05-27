//
// Created by alex on 25/05/22.
//

#ifndef DRAWABLEHITCIRCLE_H
#define DRAWABLEHITCIRCLE_H

#include "../../Drawable.h"
#include "../../../include/osu!parser/Parser/Structures/Beatmap/HitObject.hpp"

class DrawableHitCircle : public Drawable {
private:
    Parser::HitObject& baseHitObject;
public:
    DrawableHitCircle(Parser::HitObject& baseHitObject);

    void OnAdd(Drawable &parent) override;

    void OnRemove();

    void OnRender(Graphics &g) override;

    void OnUpdate(float deltaTime) override;

    bool OnEvent(SDL_Event &e) override;
};



#endif //DRAWABLEHITCIRCLE_H
