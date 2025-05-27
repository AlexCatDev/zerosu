#include "PlayScene.h"

#include "MenuScene.h"
#include "SceneManager.h"
#include "TestScene.h"
#include "../../include/osu!parser/Parser.hpp"
#include "../Easy2D/Viewport.h"
#include "../Drawable.h"
#include "../Osu/Objects/DrawableHitCircle.h"
#include "../../include/imgui/imgui.h"
#include "../Easy2D/Utils.h"
#include "../Osu/Objects/DrawableHitSlider.h"
#include "../../include/un4seen/bass.h"

class PlayableBeatmap {
private:
    static float mapDifficultyRange(float difficulty, float min, float mid, float max)
    {
        if (difficulty > 5.0f)
            return mid + (max - mid) * (difficulty - 5.0f) / 5.0f;

        if (difficulty < 5.0f)
            return mid - (mid - min) * (5.0f - difficulty) / 5.0f;

        return mid;
    }

    std::string m_FolderPath;
    std::string m_MapFileName;
    std::vector<Drawable*> m_HitObjects;
    Parser::Beatmap* m_Beatmap = nullptr;

    //Difficulty
    float m_AR=0.0f;
    float m_PreemptTime = 0.0f;
    float m_FadeinTime = 0.0f;

    float m_CS=0.0f;
    float m_circleSizeInOsuPixels = 0.0f;

    float m_OD=0.0f;
    float m_HP=0.0f;
public:
    PlayableBeatmap(const std::string& folderPath, const std::string& mapFileName) : m_FolderPath(folderPath), m_MapFileName(mapFileName)
    {
        loadBeatmap();

        loadObjects();
    }

    void UpdateARCSEtc(const float ar, const float cs, const float od, const float hp) {
        if (!m_Beatmap)
            return;

        m_AR = ar;
        m_CS = cs;
        m_OD = od;
        m_HP = hp;

        m_PreemptTime = mapDifficultyRange(ar, 1800.0f, 1200.0f, 450.0f);
        m_FadeinTime = 400.0f * std::min(1.0f, m_PreemptTime / 450.0f);

        m_circleSizeInOsuPixels = 54.4f - 4.48f * cs;
    }

private:
    void loadBeatmap() {
        m_Beatmap = new Parser::Beatmap(m_FolderPath + "/" + m_MapFileName);

        float bmAR=std::stof(m_Beatmap->Difficulty.ApproachRate);
        float bmCS=std::stof(m_Beatmap->Difficulty.CircleSize);
        float bmOD=std::stof(m_Beatmap->Difficulty.OverallDifficulty);
        float bmHP=std::stof(m_Beatmap->Difficulty.HPDrainRate);

        UpdateARCSEtc(bmAR, bmCS, bmOD, bmHP);
    }

    void loadObjects() {
        if (!m_Beatmap)
            return;

        int objLayer = 0;
        glm::ivec2 lastStackPos = glm::ivec2(0);
        for (Parser::HitObject& obj : m_Beatmap->HitObjects) {
            if (obj.Type.Spinner)
                continue;

            glm::ivec2 stackPos = glm::ivec2(obj.X, obj.Y);
            if (stackPos == lastStackPos) {
                //Todo: Start Stacking
            } else
                lastStackPos = stackPos;

            if (obj.Type.HitCircle) {
                DrawableHitCircle* incommingHitCircle = new DrawableHitCircle(obj);
                incommingHitCircle->Layer = objLayer;

                m_HitObjects.push_back(incommingHitCircle);
            } else if (obj.Type.Slider) {

                DrawableHitSlider* incommingHitSlider = new DrawableHitSlider(obj);
                incommingHitSlider->Layer = objLayer;

                m_HitObjects.push_back(incommingHitSlider);
            }

            objLayer++;
        }
    }

    ~PlayableBeatmap() {
         for (const Drawable* obj : m_HitObjects) {
             delete obj;
         }

        delete m_Beatmap;
    }
};


float mapDifficultyRange(float difficulty, float min, float mid, float max)
{
    if (difficulty > 5.0f)
        return mid + (max - mid) * (difficulty - 5.0f) / 5.0f;

    if (difficulty < 5.0f)
        return mid - (mid - min) * (5.0f - difficulty) / 5.0f;

    return mid;
}

Drawable osuDContainer;
Parser::Beatmap* beatmap;
int objectIndex = 0;
float preemptTime=0;
float fadeinTime=0;
float trackTime=0;
HSTREAM bassHandle;

float circleRadiusInOsuPixels = 0.0f;

glm::vec4 playfield{ 0 };

void PlayScene::MapToPlayfield(int x, int y, glm::vec2 &out) {
    out.x = Map(x, 1, 512, playfield.x, playfield.x + playfield.z);
    out.y = Map(y, 1, 384, playfield.y, playfield.y + playfield.w);
}

float PlayScene::RealCircleSize() {
    float osuPixelsToRealPixelsScale = playfield.w / 384.0f;
    return circleRadiusInOsuPixels * osuPixelsToRealPixelsScale * 2.0f;
}

float PlayScene::GetTrackTime() {
    return trackTime;
}

float PlayScene::GetFadeinTime() {
    return fadeinTime;
}

float PlayScene::GetPreemptTime() {
    return preemptTime;
}

void PlayScene::OnEntering() {
    if(beatmap)
        delete beatmap;

    beatmap = new Parser::Beatmap("./Maps/yomiyori/map.osu");

    if (!bassHandle) {
        bassHandle = BASS_StreamCreateFile(false, "./Maps/yomiyori/yomi.mp3", 0, 0, BASS_STREAM_PRESCAN | BASS_ASYNCFILE | BASS_SAMPLE_FLOAT);
    }
    BASS_ChannelPlay(bassHandle, 1);

    auto objCount = beatmap->HitObjects.size();
    printf("Objects: %lu\n", objCount);

    float AR = std::stof(beatmap->Difficulty.ApproachRate);

    //AR=0;
    preemptTime = mapDifficultyRange(AR, 1800.0f, 1200.0f, 450.0f);
    fadeinTime = 400.0f * std::min(1.0f, preemptTime / 450.0f);

    circleRadiusInOsuPixels = 54.4f - 4.48f * std::stof(beatmap->Difficulty.CircleSize);

    printf("PreemptTime: %f FadeinTime: %f\n", preemptTime, fadeinTime);

    osuDContainer.ClearChildren();
    objectIndex=1;
    trackTime=beatmap->HitObjects[objectIndex].Time - 600;
}

void PlayScene::OnExiting() {
    
}

void PlayScene::OnUpdate(float deltaTime) {
    trackTime = (float)(BASS_ChannelBytes2Seconds(bassHandle,BASS_ChannelGetPosition(bassHandle, BASS_POS_BYTE))*1000.0);

    osuDContainer.OnUpdate(deltaTime);

    while (objectIndex < beatmap->HitObjects.size() &&  trackTime >= beatmap->HitObjects[objectIndex].Time - preemptTime) {

        if (beatmap->HitObjects[objectIndex].Type.HitCircle) {
            DrawableHitCircle* incommingHitCircle = new DrawableHitCircle(beatmap->HitObjects[objectIndex]);
            incommingHitCircle->Layer = objectIndex;

            osuDContainer.AddChild(incommingHitCircle);
        } else if (beatmap->HitObjects[objectIndex].Type.Slider) {
            DrawableHitSlider* incommingHitSlider = new DrawableHitSlider(beatmap->HitObjects[objectIndex]);
            incommingHitSlider->Layer = objectIndex;

            osuDContainer.AddChild(incommingHitSlider);
        }

        objectIndex++;
    }

    ImGui::Begin("TrackInfo");
    ImGui::Text("TrackTime: %f Objects %d Total: ", trackTime, osuDContainer.ChildrenCount(), beatmap->HitObjects.size());
    if (ImGui::DragFloat("TrackTime", &trackTime, 4.0f, 0.0f, beatmap->HitObjects[beatmap->HitObjects.size() - 1].EndTime)) {
        //printf("Yo\n");
        BASS_ChannelSetPosition(bassHandle, BASS_ChannelSeconds2Bytes(bassHandle, trackTime/1000.0), BASS_POS_BYTE);
    };
    ImGui::End();
}

void RenderPlayfield(Graphics &g) {
    static constexpr float ASPECTRATIO = 4.0f / 3.0f;

    float playfieldHeight = Viewport::GetHeight() * 0.8f;
    float playfieldWidth = playfieldHeight * ASPECTRATIO;

    if (playfieldWidth > Viewport::GetWidth()) {
        playfieldWidth = Viewport::GetWidth();
        playfieldHeight = playfieldWidth / ASPECTRATIO;
    }

    playfield.z = playfieldWidth;
    playfield.w = playfieldHeight;

    playfield.x = Viewport::GetWidth() * 0.5f - playfieldWidth * 0.5f;
    playfield.y = Viewport::GetHeight() * 0.5f - playfieldHeight * 0.5f;

    float playfieldYOffset = playfieldHeight * 0.020f;

    playfield.y += playfieldYOffset;

    //g.DrawRectangle({playfield.x, playfield.y}, {playfield.z, playfield.w }, {0, 0, 0, 1}, Texture::GetSquare(), {0, 0, 1, 1});
}

void PlayScene::OnRender(Graphics &g) {
        RenderPlayfield(g);
        osuDContainer.OnRender(g);
}

void PlayScene::OnEvent(SDL_Event &e) {
    if (e.type == SDL_KEYDOWN) {
        if (e.key.keysym.sym == SDLK_ESCAPE)
            SceneManager::SetScene<TestScene>();
        else if (e.key.keysym.sym == SDLK_m)
            SceneManager::GetScene<MenuScene>();
    }

    osuDContainer.OnEvent(e);
}


