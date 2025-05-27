#include "OsuSkin.h"
#include <string>
#include <filesystem>

OsuSkin::OsuTexture OsuSkin::LoadOsuTexture(const char* folderPath, const char* name) {
    std::string baseName(name);

    std::string file2x = std::string(folderPath) + "/" + baseName + "@2x" + ".png";
    std::string file1x = std::string(folderPath) + "/" + baseName + ".png";

    if (std::filesystem::exists(file2x)) {
        OsuTexture texture(new Texture(file2x), true);
        return texture;
    } else if (std::filesystem::exists(file1x)) {
        OsuTexture texture(new Texture(file1x), false);
        return texture;
    } else {
        return OsuTexture(nullptr, false);
    }
}

void OsuSkin::Load(const char* folderPath) {
    approachCircle=LoadOsuTexture(folderPath, "approachcircle");
    hitCircle=LoadOsuTexture(folderPath, "hitcircle");
    hitCircleOverlay=LoadOsuTexture(folderPath, "hitcircleoverlay");
}

const OsuSkin::OsuTexture OsuSkin::GetApproachCircle() {
    return approachCircle;
}

const OsuSkin::OsuTexture OsuSkin::GetHitCircle() {
    return hitCircle;
}

const OsuSkin::OsuTexture OsuSkin::GetHitCircleOverlay() {
    return  hitCircleOverlay;
}
