//
// Created by alex on 25/05/22.
//

#include "Drawable.h"

void Drawable::AddChild(Drawable* child) {
    childrenPendingAdd.emplace_back(child);
}

void Drawable::ClearChildren() {
    for (int i = 0; i < children.size(); i++) {
        children[i]->IsDead = true;
    }

    OnUpdate(0.0f);
}

int Drawable::ChildrenCount() {
    return children.size();
}

void Drawable::OnRender(Graphics &g) {
    for (int i = 0; i < children.size(); i++) {
        if (children[i]->IsVisible && !children[i]->IsDead) {
            children[i]->OnRender(g);
        }
    }
}

bool Drawable::OnEvent(SDL_Event &e) {
    for (int i = children.size() - 1; i >= 0; i--) {
        if (children[i]->IsAcceptingInput && !children[i]->IsDead) {
            bool ateEvent = children[i]->OnEvent(e);
            if (ateEvent)
                return true;
        }
    }
    return false;
}



void Drawable::OnUpdate(float deltaTime) {
    bool requireSorting = false;
    bool requireRemoval = false;

    int previousDepth = std::numeric_limits<int>::min();

    for (int i = 0; i < children.size(); i++) {
        Drawable* child = children[i];

        if (child->IsDead) {
            requireRemoval = true;
            continue;
        }

        child->OnUpdate(deltaTime);

        if (child->Layer < previousDepth) {
            requireSorting = true;
        }
        previousDepth = child->Layer;
    }

    if (requireRemoval) {
        children.erase(std::remove_if(
            children.begin(), children.end(),
            [this](Drawable* child) {
                if (child->IsDead) {
                    hashedChildren.erase(child);
                    child->OnRemove(*this);
                    return true;
                }

                return false;
            }), children.end());
    }

    if (!childrenPendingAdd.empty()) {
        for (int i = 0; i < childrenPendingAdd.size(); i++) {
            Drawable* newChild = childrenPendingAdd[i];

            if (hashedChildren.try_emplace(newChild).second) {
                newChild->IsDead=false;
                children.emplace_back(newChild);

                newChild->OnAdd(*this);
                newChild->OnUpdate(deltaTime);
            }
        }

        childrenPendingAdd.clear();

        requireSorting = true;
    }

    if (requireSorting) {
        std::sort(children.begin(), children.end(), [](const Drawable* a, const Drawable* b) {
            return a->Layer > b->Layer;
        });
    }
}

