#ifndef OSUSKIN_H
#define OSUSKIN_H

#include "../Easy2D/Texture.h"

class OsuSkin {
    struct OsuTexture {
        Texture* RealTexture;
        bool IsHD;

        OsuTexture(Texture* texture, bool isHD) : RealTexture(texture), IsHD(isHD) { }
    };
    public:

    static OsuTexture LoadOsuTexture(const char* folderPath, const char* name);

    void Load(const char* path);

    static OsuSkin& GetInstance() {
        static OsuSkin instance;
        return instance;
    }

    const OsuTexture GetApproachCircle();
    const OsuTexture GetHitCircle();
    const OsuTexture GetHitCircleOverlay();

private:
    OsuTexture approachCircle {nullptr, false};
    OsuTexture hitCircle {nullptr, false};
    OsuTexture hitCircleOverlay {nullptr, false};
};

#endif //OSUSKIN_H
