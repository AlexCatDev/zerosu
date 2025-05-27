#ifndef TESTSCENE_H
#define TESTSCENE_H

#include "Scene.h"


class TestScene : public Scene {
public:
    TestScene();

    void OnUpdate(float deltaTime) override;
    void OnRender(Graphics &g) override;
    void OnEvent(SDL_Event &e) override;
    void OnEntering() override;
    void OnExiting() override;
};



#endif //TESTSCENE_H
