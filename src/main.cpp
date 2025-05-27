#include "../include/imgui/imgui.h"
#include "../include/imgui/imgui_impl_sdl2.h"
#include "../include/imgui/imgui_impl_opengl3.h"

#include </usr/include/SDL2/SDL.h>
#include <GLES2/gl2.h>
#include "../include/glm/glm.hpp"
#include "../include/glm/gtc/type_ptr.hpp"
#include <fstream>
#include <iostream>
#include "Easy2D/Graphics.cpp"

#include "Scenes/MenuScene.h"
#include "Scenes/SceneManager.h"
#include "Scenes/PlayScene.h"
#include "Scenes/TestScene.h"

#include "./Easy2D/Viewport.h"
#include "Osu/OsuSkin.h"
#include "../include/un4seen/bass.h"
#include <chrono>

int width=1920, height = 1080;
glm::mat4 projection;

void printOpenglInfo() {
    const GLubyte* renderer = glGetString(GL_RENDERER);
    const GLubyte* vendor   = glGetString(GL_VENDOR);
    const GLubyte* version  = glGetString(GL_VERSION);

    printf("GPU Vendor: %s\n", vendor);
    printf("GPU Renderer: %s\n", renderer);
    printf("OpenGL Version: %s\n", version);

    GLint maxTextureSize;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    printf("Max texture size: %d\n", maxTextureSize);

    GLint maxTextureUnits;
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &maxTextureUnits);
    printf("Max texture units in fragment shader: %d\n", maxTextureUnits);

    const char* extensions = (const char*)glGetString(GL_EXTENSIONS);

    if (!extensions) {
        printf("No extensions\n");
        return;
    }

    std::string extStr(extensions);

    std::istringstream iss(extStr);
    std::vector<std::string> extensionsList;

    while (iss >> extStr) {
        extensionsList.emplace_back(extStr);
    }

    std::cout << "OpenGL Extensions: " << std::endl;

    for (const auto& ext : extensionsList) {
        std::cout << ext << std::endl;
    }

}

void renderImGui(Graphics& g, int fps, double delta) {
    static int imGuiVtxCount = 0;
    static int imGuiIdxCount = 0;
    static int imGuiCmdListCount = 0;

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplSDL2_NewFrame();
    ImGui::NewFrame();
    ImGui::SetNextWindowPos(ImVec2(10, 10));
    ImGui::Begin("Debug", 0, ImGuiWindowFlags_NoResize);
    ImGui::Text("FPS: %d %.2f", (int)(1.0/delta), delta*1000.0);
    ImGui::Text("Graphics Vtx: %d Idx: %d DrawCalls: %d Textures: %d",
        Graphics::Statistics.Vertices, Graphics::Statistics.Indices, Graphics::Statistics.DrawCalls, Graphics::Statistics.Textures);
    ImGui::Text("ImGui Vtx: %d Idx: %d CmdLists: %d",
        imGuiVtxCount, imGuiIdxCount, imGuiCmdListCount);
    Graphics::Statistics.Reset();
    ImGui::End();

    ImGui::Render();
    ImDrawData* drawData = ImGui::GetDrawData();

    imGuiVtxCount = drawData->TotalVtxCount;
    imGuiIdxCount = drawData->TotalIdxCount;
    imGuiCmdListCount = drawData->CmdListsCount;

    ImGui_ImplOpenGL3_RenderDrawData(drawData);
}

void imGuiInit(SDL_Window* window, SDL_GLContext* context) {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls
    io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange;           // Enable Docking

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForOpenGL(window, context);
    const char* glsl_version = "#version 100";
    ImGui_ImplOpenGL3_Init(glsl_version);
}

void windowResized(int w, int h)
{
    //printf("Window resized: %dx%d\n", w, h);
    Viewport::Set(0, 0, w, h);
    projection= glm::ortho(0.0f, (float)w, (float)h, 0.0f);
}

int main(int argc, char* argv[]) {

    printf("Size: %dx%d\n", width, height);

    // SDL init
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "SDL init failed: " << SDL_GetError() << std::endl;
        return 1;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);

    //SDL_ShowCursor(SDL_DISABLE);

    SDL_Window* window = SDL_CreateWindow("app",
                                          SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                          width, height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

    /*
    SDL_DisplayMode mode;
    mode.w = 640;              // width
    mode.h = 480;              // height
    mode.format = SDL_PIXELFORMAT_RGBA8888;  // pixel format
    mode.refresh_rate = 120;     // refresh rate in Hz
    mode.driverdata = nullptr;        // usually 0

    // Set display mode for the window (not fullscreen yet)
    SDL_SetWindowDisplayMode(window, &mode);

    // Then switch to fullscreen with that mode
    SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);
    */

    if (!window) {
        std::cerr << "Window creation failed: " << SDL_GetError() << std::endl;
        SDL_Quit();
        return 1;
    }

    if (!BASS_Init(-1, 44100, BASS_DEVICE_LATENCY | BASS_DEVICE_STEREO, nullptr, nullptr)) {
        int bassErr = BASS_ErrorGetCode();

        printf("Couldn't init bass: %d\n", bassErr);
    }else {
        auto bassVer = BASS_GetVersion();
        BASS_INFO info;
        auto latency = BASS_GetInfo(&info);
        printf("Bass loaded: %d Latency: %d Speakers: %d\n", bassVer, info.latency, info.speakers);

    }

    SDL_GLContext context = SDL_GL_CreateContext(window);
    if (!context) {
        std::cerr << "GL context creation failed: " << SDL_GetError() << std::endl;
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    printOpenglInfo();

    SDL_GL_SetSwapInterval(0);

    imGuiInit(window, &context);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f); // Background
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_SCISSOR_TEST);

    windowResized(width, height);

    Graphics g;

    SceneManager::RegisterScene<TestScene>();
    SceneManager::RegisterScene<MenuScene>();
    SceneManager::RegisterScene<PlayScene>();

    OsuSkin::GetInstance().Load("./Skins/default");

    //main loopity loop loop
    bool running = true;
    SDL_Event event;
    auto lastTime = std::chrono::high_resolution_clock::now();
    int frames = 0;
    float frameTime = 0.0f;

    int imGuiVtxCount = 0;
    int imGuiIdxCount = 0;
    int imGuiCmdListCount = 0;
    while (running) {
        while (SDL_PollEvent(&event)) {
            ImGui_ImplSDL2_ProcessEvent(&event);
            SceneManager::OnEvent(event);

            switch (event.type) {
                case SDL_WINDOWEVENT:
                    if (event.window.event == SDL_WINDOWEVENT_RESIZED) {
                        width = event.window.data1;
                        height = event.window.data2;
                        windowResized(width, height);
                    }
                    break;
                case SDL_QUIT:
                    running = false;
                    break;
                }
            }

        auto start = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> Ddelta = start - lastTime;

        float delta = static_cast<float>(Ddelta.count());
        lastTime = start;

        frames++;
        frameTime += delta;
        if (frameTime >= 1.0f) {
            printf("FPS: %d\n", frames);
            frameTime -= 1.0f;
            frames = 0;
        }

        int x, y;
        SDL_GetMouseState(&x, &y);

        glClear(GL_COLOR_BUFFER_BIT);

        g.Projection = projection;

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui::NewFrame();

        {
            ProfileObject t("SceneManager::OnUpdate");
            SceneManager::OnUpdate(delta);
        }

        {
            ProfileObject t("SceneManager::OnRender");
            SceneManager::OnRender(g);
        }

        ImGui::Begin("Debug");
        ImGui::Text("FPS: %d %.2f", (int)(1.0/delta), delta*1000.0f);
        ImGui::Text("Graphics Vtx: %d Idx: %d DrawCalls: %d Textures: %d",
            Graphics::Statistics.Vertices, Graphics::Statistics.Indices, Graphics::Statistics.DrawCalls, Graphics::Statistics.Textures);
        ImGui::Text("ImGui Vtx: %d Idx: %d CmdLists: %d",
            imGuiVtxCount, imGuiIdxCount, imGuiCmdListCount);

        std::unordered_map<const char*, double> profiles = ProfileObject::GetProfiles();

        for (auto& profile : profiles) {
            int microseconds = static_cast<int>(profile.second * 1000.0);
            ImGui::Text("%s: %d µs", profile.first, microseconds);
        }

        ImGui::End();

        Graphics::Statistics.Reset();

        //g.DrawRectangle(glm::vec2(x, y) - glm::vec2(25, 25),
    //glm::vec2(50, 50),
    //glm::vec4(1.0f, glm::sin(frameTime), 1.0f, 1.0f),
    //Texture::GetCircle(), glm::vec4(0.0f, 0.0f, 1.0f, 1.0f)
    //);

        g.Render();

        ImGui::Render();
        ImDrawData* drawData = ImGui::GetDrawData();

        imGuiVtxCount = drawData->TotalVtxCount;
        imGuiIdxCount = drawData->TotalIdxCount;
        imGuiCmdListCount = drawData->CmdListsCount;

        ImGui_ImplOpenGL3_RenderDrawData(drawData);

        //renderImGui(g, frames, delta);
        {
            ProfileObject t("SwapWindow");
            SDL_GL_SwapWindow(window);
        }
    }

    // Cleanup
    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}