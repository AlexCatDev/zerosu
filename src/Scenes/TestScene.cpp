#include "TestScene.h"

#include "PlayScene.h"
#include "../Easy2D/Utils.h"
#include "SceneManager.h"

struct Ball {
    glm::vec2 Position = glm::vec2(0.0f);
    glm::vec2 Velocity = glm::vec2(0.0f);
    glm::vec4 Color = glm::vec4(0.0f);
};

Ball balls[100];
glm::vec2 ballSize = glm::vec2(30.0f);

int sWidth=1280, sHeight = 720;

void kek(const Graphics& lol){

}

TestScene::TestScene()
{
    for (int i = 0; i < std::size(balls); i++) {
        balls[i].Position = glm::vec2(GetRandomFloat(1, sWidth - 1), GetRandomFloat(1, sHeight - 1));
        balls[i].Velocity = glm::vec2(GetRandomFloat(50, 200), GetRandomFloat(50, 200));

        if (GetRandomFloat() >= 0.5f)
        {
            balls[i].Velocity.x *= -1;
        }

        if (GetRandomFloat() >= 0.5f)
        {
            balls[i].Velocity.y *= -1;
        }

        balls[i].Color = glm::vec4(
            GetRandomFloat(0.1f, 0.9f),
            GetRandomFloat(0.1f, 0.9f),
            GetRandomFloat(0.1f, 0.9f),
            1.0f);
    }
}

void TestScene::OnEntering() {

}

void TestScene::OnExiting() {

}

void TestScene::OnUpdate(float deltaTime) {
    for (int i = 0; i < std::size(balls); i++) {
        balls[i].Position += balls[i].Velocity * deltaTime;

        if (balls[i].Position.x < 0) {
            balls[i].Position.x = 0;
            balls[i].Velocity.x *= -1;
        }else if (balls[i].Position.x > sWidth - ballSize.x) {
            balls[i].Position.x = sWidth - ballSize.x;
            balls[i].Velocity.x *= -1;
        }

        if (balls[i].Position.y < 0) {
            balls[i].Position.y = 0;
            balls[i].Velocity.y *= -1;
        }else if (balls[i].Position.y > sHeight - ballSize.y) {
            balls[i].Position.y = sHeight - ballSize.y;
            balls[i].Velocity.y *= -1;
        }
    }
}

void TestScene::OnRender(Graphics &g) {
    for (int i = 0; i < std::size(balls); i++) {
        g.DrawRectangle(balls[i].Position, ballSize, balls[i].Color, Texture::GetCircle(), glm::vec4(0.0f, 0.0f, 1.0f, 1.0f));
    }
}

void TestScene::OnEvent(SDL_Event &e) {
    if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_w) {
        SceneManager::SetScene<PlayScene>();
    }
}
