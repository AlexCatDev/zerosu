#include "SceneManager.h"

Scene* SceneManager::currentScene = nullptr;
std::unordered_map<int, Scene*> SceneManager::scenes;

void SceneManager::OnUpdate(float deltaTime) {
    if (currentScene) {
        currentScene->OnUpdate(deltaTime);
    }
}

void SceneManager::OnRender(Graphics& g) {
    if (currentScene) {
        currentScene->OnRender(g);
    }
}

void SceneManager::OnEvent(SDL_Event& e) {
    if (currentScene) {
        currentScene->OnEvent(e);
    }
}



