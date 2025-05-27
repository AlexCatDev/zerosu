#ifndef PLAYSCREEN_H
#define PLAYSCREEN_H

#include "Scene.h"

class PlayScene : public Scene {
public:
    PlayScene() = default;

    void OnUpdate(float deltaTime) override;
    void OnRender(Graphics &g) override;
    void OnEvent(SDL_Event &e) override;
    void OnEntering() override;
    void OnExiting() override;

    static void MapToPlayfield(int x, int y, glm::vec2 &out);
    static float RealCircleSize();

    static float GetTrackTime();
    static float GetFadeinTime();
    static float GetPreemptTime();
};



#endif //PLAYSCREEN_H
