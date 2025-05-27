#pragma once

class GLObject
{
#define UninitializedHandle -6969

protected:
    unsigned int handle = UninitializedHandle;

    virtual void initialize() = 0;
    virtual void bind(int slot) = 0;
    virtual void release() = 0;

public:
    /// <summary>
    /// Bind an object
    /// </summary>
    /// <param name="slot">The slot to bind the object to, only used for textures</param>
    void Bind(int slot = 0) {
        if (IsInitialized())
            bind(slot);
        else
            initialize();
    }

    bool IsInitialized() const {
        return handle != UninitializedHandle;
    }

    void Release() {
        if (IsInitialized())
            release();
    }

    virtual ~GLObject() {
        Release();
    }
};