#ifndef SCENE_H
#define SCENE_H

#include "../Easy2D/Graphics.cpp"
#include <SDL2/SDL.h>

class Scene {
public:
    virtual void OnUpdate(float deltaTime)=0;
    virtual void OnRender(Graphics& g)=0;
    virtual void OnEvent(SDL_Event& e)=0;
    virtual void OnEntering()=0;
    virtual void OnExiting()=0;
};



#endif //SCENE_H
