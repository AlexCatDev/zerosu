//
// Created by alex on 25/05/22.
//

#ifndef DRAWABLE_H
#define DRAWABLE_H

#include "./Easy2D/Graphics.cpp"
#include <SDL2/SDL.h>

class Drawable {
    public:
    virtual ~Drawable()=default;

    Drawable()=default;

    int Layer = 0;

    bool IsDead = false;

    bool IsVisible = true;
    bool IsAcceptingInput = true;

    virtual void OnAdd(Drawable& parent){};
    virtual void OnRemove(Drawable& parent){};

    virtual void OnRender(Graphics &g);
    virtual void OnUpdate(float deltaTime);
    virtual bool OnEvent(SDL_Event &e);

    private:
        //Todo: probably make these use shared_pointers otherwise it's gonna become really fucking messy (rohulk level) to manage drawables and their memory lifetimes
    std::vector<Drawable*> children;
    std::unordered_map<Drawable*, int> hashedChildren;
    std::vector<Drawable*> childrenPendingAdd;
    //Children interface
public:
    void AddChild(Drawable* child);
    void ClearChildren();
    int ChildrenCount();

    const char* Name = "";
};



#endif //DRAWABLE_H
