#ifndef MENUSCENE_H
#define MENUSCENE_H

#include "Scene.h"

class MenuScene : public Scene{
public:
    MenuScene() = default;

    void OnUpdate(float deltaTime) override;
    void OnRender(Graphics &g) override;
    void OnEvent(SDL_Event &e) override;
    void OnEntering() override;
    void OnExiting() override;
};



#endif //MENUSCENE_H
