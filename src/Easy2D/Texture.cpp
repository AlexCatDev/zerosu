#include "Texture.h"

#define STB_IMAGE_IMPLEMENTATION
#include "../../include/stb/stb_image.h"

#include <iostream>

Texture::Texture(const char* filename)
    : filename(filename), width(0), height(0) {}

Texture::Texture(std::string filename)
    : filename(filename), width(0), height(0) {}

Texture::Texture(int w, int h, GLint internalFmt, GLint fmt, GLint type)
    : filename(nullptr), width(w), height(h),
      internalFormat(internalFmt), format(fmt), pixelType(type) {}

void Texture::initialize() {
    if (handle != UninitializedHandle)
        return;  // Already initialized

    glGenTextures(1, &handle);
    bind(0);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    if (filename != "") {
        int channels;
        unsigned char* pixels = stbi_load(filename.c_str(), &width, &height, &channels, 4);
        if (!pixels) {
            std::cerr << "Failed to load texture: " << filename << std::endl;
            return;
        }
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, pixels);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glGenerateMipmap(GL_TEXTURE_2D);  // if generating manually

        stbi_image_free(pixels);
    }
    else {
        // Empty texture data (null)
        glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, width, height, 0,
                     format, pixelType, nullptr);
    }
}

void Texture::bind(int slot) {
    glActiveTexture(GL_TEXTURE0 + slot);
    glBindTexture(GL_TEXTURE_2D, handle);
}

void Texture::release() {
    glDeleteTextures(1, &handle);
    handle = UninitializedHandle;
}


const Texture* Texture::SQUARE_TEXTURE = nullptr;
const Texture* Texture::CIRCLE_TEXTURE = nullptr;

const Texture* Texture::GetSquare() {
    if (!Texture::SQUARE_TEXTURE)
        Texture::SQUARE_TEXTURE = new Texture("./textures/square.png" );

    return Texture::SQUARE_TEXTURE;
}
const Texture* Texture::GetCircle() {
    if (!Texture::CIRCLE_TEXTURE)
        Texture::CIRCLE_TEXTURE = new Texture("./textures/circle.png" );

    return Texture::CIRCLE_TEXTURE;
}