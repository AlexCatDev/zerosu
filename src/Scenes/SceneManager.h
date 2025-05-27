#ifndef SCENEMANAGER_H
#define SCENEMANAGER_H

#include <SDL2/SDL.h>
#include "../Easy2D/Graphics.cpp"
#include "Scene.h"

class SceneManager {
public:
    SceneManager() = delete;
    ~SceneManager() = delete;

    template<typename T>
    static void RegisterScene() {
        int typeId = getSceneTypeID<T>();

        if (scenes.find(typeId) != scenes.end()) {
            printf("FAIL Scene with ID %d already registered\n", typeId);
            return;
        }

        Scene* scene = new T();

        scenes.emplace(typeId, scene);

        printf("Registered Scene ID: %d\n", typeId);

        if (!currentScene) {
            printf("No Current Scene, Set Current to ID: %d\n", typeId);
            currentScene = scene;
        }
    }

    template<typename T>
    static void SetScene() {
        int typeId = getSceneTypeID<T>();

        std::unordered_map<int, Scene *>::iterator iter = scenes.find(typeId);

        if (iter == scenes.end()) {
            printf("FAIL Scene with ID %d not registered\n", typeId);
            return;
        }else {
            currentScene->OnExiting();

            currentScene = iter->second;
            currentScene->OnEntering();
            printf("Set Current Scene to ID: %d\n", typeId);
        }
    }

    template<typename T>
    static T* GetScene() {
        int typeId = getSceneTypeID<T>();

        std::unordered_map<int, Scene *>::iterator iter = scenes.find(typeId);

        if (iter == scenes.end()) {
            printf("FAIL Scene with ID %d not registered\n", typeId);
            return nullptr;
        } else {
            T* foundScene = static_cast<T*>(iter->second);
            return foundScene;
        }
    }

    static void OnUpdate(float deltaTime);
    static void OnRender(Graphics& g);
    static void OnEvent(SDL_Event& e);

private:
    static std::unordered_map<int, Scene*> scenes;
    static Scene* currentScene;

    template<typename T>
    static int getSceneTypeID() {
        static const int id = generateNewTypeID();
        return id;
    }

    static int generateNewTypeID() {
        static int nextId = 0;
        return nextId++;
    }
};


#endif //SCENEMANAGER_H
