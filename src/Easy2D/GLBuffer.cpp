#pragma once
#include "GLObject.cpp"
#include "Log.cpp"
#include <iomanip>
#include <GLES2/gl2.h>

template<typename T>
class GLBuffer :
    public GLObject
{
    GLenum target, usage;
    unsigned int typeSize;
    unsigned int capacity;

public:
    //Delete copy constructor?
    GLBuffer(const GLBuffer &buffer) = delete;

    GLBuffer(GLenum target, GLenum usage, unsigned int capacity) {
        this->target = target;
        this->usage = usage;
        this->capacity = capacity;

        typeSize = sizeof(T);
    }

    void UploadData(const T* data, int offset, int length) {
        Bind();

        int size = length * typeSize;
        //Orphan buffer, small speed increase
        glBufferData(target, size, nullptr, usage);
        glBufferSubData(target, offset, size, data);
    }

    unsigned int GetCapacity() { return capacity; }

    void Resize(int newCapacity) {
        if (IsInitialized()) {
            bind();
            glBufferData(target, newCapacity * typeSize, nullptr, usage);
        }

        this->capacity = newCapacity;
    }

private:
    void release() {
        glDeleteBuffers(1, &handle);
        handle = UninitializedHandle;
    }

    void bind(int slot = 0) {
        glBindBuffer(target, handle);
    }

    void initialize() {
        glGenBuffers(1, &handle);
        bind();

        glBufferData(target, capacity * typeSize, nullptr, usage);

        LogBufferInit(capacity, typeSize, target, usage);
    }

    static void LogBufferInit(size_t capacity, size_t typeSize, GLint target, GLint usage)
    {
        /*
        Log((std::format("GLBuffer Initialized elements: {} type_size: {} bytes target: {} usage: {} {:.2f} KB",
            capacity,
            typeSize,
            GetTargetString(target),
            GetUsageString(usage),
            (capacity * typeSize) / 1024.0
            )).c_str(), LogLevel::Info);
        */
        double sizeKB = static_cast<double>(capacity * typeSize) / 1024.0;

        std::ostringstream oss;
        oss << "GLBuffer Initialized elements: " << capacity
            << " type_size: " << typeSize << " bytes"
            << " target: " << GetTargetString(target)
            << " usage: " << GetUsageString(usage)
            << " " << std::fixed << std::setprecision(2) << sizeKB << " KB";

        Log(oss.str().c_str(), LogLevel::Info);
    }

    static const char* GetTargetString(GLenum target ) {
        switch (target) {
        case GL_ARRAY_BUFFER:
            return "GL_ARRAY_BUFFER";
        case GL_ELEMENT_ARRAY_BUFFER:
            return "GL_ELEMENT_ARRAY_BUFFER";
        default:
            return "Unknown";
        }
    }

    static const char* GetUsageString(GLenum usage) {
        switch (usage) {
        case GL_STATIC_DRAW:
            return "GL_STATIC_DRAW";
        case GL_DYNAMIC_DRAW:
            return "GL_DYNAMIC_DRAW";
        case GL_STREAM_DRAW:
            return "GL_STREAM_DRAW";
        default:
            return "Unknown";
        }
    }
};