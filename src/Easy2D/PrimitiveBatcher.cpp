#pragma once
#include <type_traits>
#include <cstdint>
#include <functional>
#include <stdexcept>
#include "GLBuffer.cpp"

template<typename T>
class PrimitiveBatcher {
    static_assert(std::is_trivially_copyable_v<T>, "T must be trvially copyable");

    public:

    std::function<void()> OutOfMemoryCallback;

    PrimitiveBatcher(uint16_t vertexCapacity, uint16_t indexCapacity)
    : vertexCapacity(vertexCapacity), indexCapacity(indexCapacity) {

        vertexBuffer = new T[vertexCapacity];
        gl_vertexBuffer = new GLBuffer<T>(GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW, vertexCapacity);

        indexBuffer = new uint16_t[indexCapacity];
        gl_indexBuffer = new GLBuffer<uint16_t>(GL_ELEMENT_ARRAY_BUFFER, GL_DYNAMIC_DRAW, indexCapacity);
    }

    ~PrimitiveBatcher() {
        delete[] vertexBuffer;
        delete[] indexBuffer;

        delete gl_vertexBuffer;
        delete gl_indexBuffer;
    }

    T* GetTriangle() {
        ensureCapacity(3, 3);
        indexBuffer[indicesPending + 0] = verticesPending + 0;
        indexBuffer[indicesPending + 1] = verticesPending + 1;
        indexBuffer[indicesPending + 2] = verticesPending + 2;
        indicesPending += 3;
        verticesPending += 3;
        return vertexBuffer + verticesPending - 3;
    }

    T* GetQuad() {
        ensureCapacity(4, 6);
        indexBuffer[indicesPending + 0] = verticesPending + 0;
        indexBuffer[indicesPending + 1] = verticesPending + 1;
        indexBuffer[indicesPending + 2] = verticesPending + 2;
        indexBuffer[indicesPending + 3] = verticesPending + 0;
        indexBuffer[indicesPending + 4] = verticesPending + 2;
        indexBuffer[indicesPending + 5] = verticesPending + 3;
        indicesPending += 6;
        verticesPending += 4;
        return vertexBuffer + verticesPending - 4;
    }

    T* GetTriangleStrip(uint16_t pointCount) {
        if (pointCount < 3) return nullptr;
        ensureCapacity(pointCount, (pointCount - 2) * 3);

        for (uint16_t i = 0; i < pointCount - 2; ++i) {
            indexBuffer[indicesPending + 0] = verticesPending + i;
            indexBuffer[indicesPending + 1] = verticesPending + i + 1;
            indexBuffer[indicesPending + 2] = verticesPending + i + 2;
            indicesPending += 3;
        }

        verticesPending += pointCount;
        return vertexBuffer + verticesPending - pointCount;
    }

    T* GetTriangleFan(uint16_t pointCount) {
        if (pointCount < 3) return nullptr;
        ensureCapacity(pointCount, (pointCount - 2) * 3);

        for (uint16_t i = 1; i < pointCount - 1; ++i) {
            indexBuffer[indicesPending + 0] = verticesPending;
            indexBuffer[indicesPending + 1] = verticesPending + i;
            indexBuffer[indicesPending + 2] = verticesPending + i + 1;
            indicesPending += 3;
        }

        verticesPending += pointCount;
        return vertexBuffer + verticesPending - pointCount;
    }

    void Reset() {
        verticesPending = 0;
        indicesPending = 0;
    }

    void Upload() {
        gl_vertexBuffer->UploadData(vertexBuffer, 0, verticesPending);
        gl_indexBuffer->UploadData(indexBuffer, 0, indicesPending);
    }

    uint16_t GetPendingIndicesCount() const { return indicesPending; }
    uint16_t GetPendingVerticesCount() const { return verticesPending; }

private:
    void ensureCapacity(uint32_t vCount, uint32_t iCount) {
        if (indicesPending + iCount > indexCapacity) {
            if (OutOfMemoryCallback) OutOfMemoryCallback();
            if (indicesPending + iCount > indexCapacity)
                throw std::runtime_error("Index buffer overflow.");
        }

        if (verticesPending + vCount > vertexCapacity) {
            if (OutOfMemoryCallback) OutOfMemoryCallback();
            if (verticesPending + vCount > vertexCapacity)
                throw std::runtime_error("Vertex buffer overflow.");
        }
    }

    T* vertexBuffer = nullptr;
    GLBuffer<T>* gl_vertexBuffer = nullptr;

    GLBuffer<uint16_t>* gl_indexBuffer = nullptr;
    uint16_t* indexBuffer = nullptr;

    uint16_t verticesPending = 0;
    uint16_t indicesPending = 0;

    uint16_t vertexCapacity = 0;
    uint16_t indexCapacity = 0;
};
