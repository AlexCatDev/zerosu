#pragma once
#include "Shader.cpp"
#include "PrimitiveBatcher.cpp"
#include "Texture.h"
#include "Utils.h"

class Graphics {
private:
    struct Vertex {
        glm::vec2 Position;
        glm::vec2 TexCoord;
        glm::vec4 Color;
        float TextureID;

        static void enableVertexAttribs()
        {
            glEnableVertexAttribArray(0);
            glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)0);

            glEnableVertexAttribArray(1);
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)8);

            glEnableVertexAttribArray(2);
            glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)16);

            glEnableVertexAttribArray(3);
            glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)32);
        }
    };

    public:
    void DrawRectangle(glm::vec2 position, glm::vec2 size, glm::vec4 color, const Texture* const texture, glm::vec4 textureRect, bool uvNormalized = true) {
#define texWidth textureRect.z
#define texHeight textureRect.w

        Vertex* quad = batcher->GetQuad();

        int textureSlot = GetTextureSlot(texture);

        glm::vec2 rotationOrigin = position;

        quad[0].Position = position;
        //quad[0].Rotation = rotation;
        quad[0].TextureID = textureSlot;
        quad[0].Color = color;
        //quad[0].RotationOrigin = rotationOrigin;
        quad[0].TexCoord = glm::vec2(textureRect.x, textureRect.y);

        quad[1].Position = glm::vec2(position.x + size.x, position.y);
        //quad[1].Rotation = rotation;
        quad[1].TextureID = textureSlot;
        quad[1].Color = color;
        //quad[1].RotationOrigin = rotationOrigin;
        quad[1].TexCoord = glm::vec2(textureRect.x + texWidth, textureRect.y);

        quad[2].Position = position + size;
        //quad[2].Rotation = rotation;
        quad[2].TextureID = textureSlot;
        quad[2].Color = color;
        //quad[2].RotationOrigin = rotationOrigin;
        quad[2].TexCoord = glm::vec2(textureRect.x + texWidth, textureRect.y + texHeight);

        quad[3].Position = glm::vec2(position.x, position.y + size.y);
        //quad[3].Rotation = rotation;
        quad[3].TextureID = textureSlot;
        quad[3].Color = color;
        //quad[3].RotationOrigin = rotationOrigin;
        quad[3].TexCoord = glm::vec2(textureRect.x, textureRect.y + texHeight);
    }

    constexpr static int MaxTextureSlots = 4;

    glm::mat4 Projection {0};

    Graphics() {
        shader = new Shader("./shaders/main.vert", "./shaders/main.frag");

        uint16_t maxCapacity = std::numeric_limits<uint16_t>::max();

        batcher = new PrimitiveBatcher<Vertex>(maxCapacity, maxCapacity);
        batcher->OutOfMemoryCallback = [this]() {
            Render();
        };
    }

    void Render() {
        {
            ProfileObject t("Bind Textures");
            for (std::map<Texture*, int>::const_iterator it = textureMap.begin(); it != textureMap.end(); ++it) {
                Texture* texture = it->first;
                int bindSlot = it->second;

                texture->Bind(bindSlot);
            }
        }

        {
            ProfileObject t("Batcher Upload Data");
            batcher->Upload();
        }

        Vertex::enableVertexAttribs();

        {
            ProfileObject t("Graphics::shader->Bind");
            shader->Bind();
            shader->SetMatrix("u_Projection", Projection);
            shader->SetInt("u_tex0", 0);
            shader->SetInt("u_tex1", 1);
            shader->SetInt("u_tex2", 2);
            shader->SetInt("u_tex3", 3);
        }

        {
            ProfileObject t("glDrawElements");
            glDrawElements(GL_TRIANGLES, batcher->GetPendingIndicesCount(), GL_UNSIGNED_SHORT, nullptr);
        }

        Statistics.DrawCalls++;
        Statistics.Vertices += batcher->GetPendingVerticesCount();
        Statistics.Indices += batcher->GetPendingIndicesCount();
        Statistics.Textures += bindSlotIndex;

        bindSlotIndex = 0;
        textureMap.clear();

        batcher->Reset();

        //std::cout << "indices drawn: " << batcher->GetPendingIndicesCount() << std::endl;
    }
private:
    Shader* shader;
    PrimitiveBatcher<Vertex>* batcher;

    int bindSlotIndex = 0;

    std::map<Texture*, int> textureMap;

    int GetTextureSlot(const Texture* texture) {
        if (texture == nullptr)
            texture = Texture::GetSquare();

        auto p = textureMap.find(const_cast<Texture*>(texture));

        //Not in the list
        if (p == textureMap.end()) {
            if (bindSlotIndex >= MaxTextureSlots) {
                Render();
                //Log("Texture slot overflow, resetting", LogLevel::Warning);
            }

            int slotToAdd = bindSlotIndex;

            bindSlotIndex++;

            textureMap.insert(std::pair<Texture*, int>((Texture*)texture, slotToAdd));

            return slotToAdd;
        }

        return p->second;
    }
public:
    ~Graphics() {
        delete shader;
        //delete batcher;
    }

    struct STATISTICS {
        int DrawCalls = 0;
        int Vertices = 0;
        int Indices = 0;
        int Textures = 0;

        void Reset() {
            DrawCalls = 0;
            Vertices = 0;
            Indices = 0;
            Textures = 0;
        }
    } static inline Statistics {0,0,0,0};
};

//Graphics::STATISTICS Graphics::Statistics ;