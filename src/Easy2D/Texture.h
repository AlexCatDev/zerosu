#pragma once

#include <string>

#include "GLObject.cpp"
#include <GLES2/gl2.h>

class Texture : public GLObject {
public:
    //delet copy constructor
    Texture(const Texture&) = delete;
    Texture& operator=(const Texture&) = delete;

    explicit Texture(const char* filename);
    explicit Texture(std::string filename);
    Texture(int width, int height,
            GLint internalFormat = GL_RGBA,
            GLint format = GL_RGBA,
            GLint pixelType = GL_UNSIGNED_BYTE);

    void initialize() override;
    void bind(int slot) override;
    void release() override;

    int GetWidth() const { return width; }
    int GetHeight() const { return height; }

    const static Texture* GetSquare();
    const static Texture* GetCircle();

private:
    static const Texture* SQUARE_TEXTURE;
    static const Texture* CIRCLE_TEXTURE;

    std::string filename = "";
    int width = 0, height = 0;
    GLint internalFormat = GL_RGBA;
    GLint format = GL_RGBA;
    GLint pixelType = GL_UNSIGNED_BYTE;
};