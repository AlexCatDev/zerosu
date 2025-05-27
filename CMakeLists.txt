cmake_minimum_required(VERSION 3.25.1)
project(zerosu)

set(CMAKE_CXX_STANDARD 20)

find_package(OpenGL REQUIRED)
find_package(SDL2 REQUIRED)

add_executable(zerosu src/main.cpp
        src/Easy2D/GLObject.cpp
        src/Easy2D/Log.cpp
        src/Easy2D/GLBuffer.cpp
        src/Easy2D/Texture.cpp
        src/Easy2D/Shader.cpp
        src/Easy2D/PrimitiveBuilder.cpp
        src/Easy2D/Graphics.cpp
        src/Easy2D/PrimitiveBatcher.cpp
        src/Easy2D/Texture.h
        src/Scenes/Scene.cpp
        src/Scenes/Scene.h
        src/Scenes/PlayScene.cpp
        src/Scenes/PlayScene.h
        src/Scenes/SceneManager.cpp
        src/Scenes/SceneManager.h
        include/imgui/imconfig.h
        include/imgui/imgui.cpp
        include/imgui/imgui.h
        include/imgui/imgui_demo.cpp
        include/imgui/imgui_draw.cpp
        include/imgui/imgui_impl_opengl3.cpp
        include/imgui/imgui_impl_opengl3.h
        include/imgui/imgui_impl_opengl3_loader.h
        include/imgui/imgui_impl_sdl2.cpp
        include/imgui/imgui_impl_sdl2.h
        include/imgui/imgui_internal.h
        include/imgui/imgui_tables.cpp
        include/imgui/imgui_widgets.cpp
        include/imgui/imstb_rectpack.h
        include/imgui/imstb_textedit.h
        include/imgui/imstb_truetype.h
        src/Scenes/MenuScene.cpp
        src/Scenes/MenuScene.h
        src/Easy2D/Utils.h
        src/Scenes/TestScene.cpp
        src/Scenes/TestScene.h
        src/Easy2D/Viewport.h
        src/Osu/OsuSkin.h
        src/Osu/OsuSkin.cpp
        src/Osu/Objects/DrawableHitCircle.cpp
        src/Osu/Objects/DrawableHitCircle.h
        src/Drawable.cpp
        src/Drawable.h
        src/Easy2D/Viewport.cpp
        src/Osu/Objects/DrawableHitSlider.cpp
        src/Osu/Objects/DrawableHitSlider.h
        src/Osu/Objects/CurveApproximator.h
        src/Osu/Objects/Path.h
)

target_include_directories(zerosu PRIVATE ${SDL2_INCLUDE_DIRS})
target_link_libraries(zerosu PRIVATE ${SDL2_LIBRARIES} OpenGL::GL)

# Paths for shader copy
set(SHADER_SOURCE_DIR "${CMAKE_SOURCE_DIR}/shaders")
set(SHADER_DEST_DIR "${CMAKE_BINARY_DIR}/shaders")

# Custom target to copy shaders folder recursively
add_custom_target(copy_shaders ALL
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${SHADER_SOURCE_DIR}"
        "${SHADER_DEST_DIR}"
        COMMENT "Copying shaders directory to build folder"
)

# Make sure your executable depends on copying shaders
add_dependencies(zerosu copy_shaders)

# Paths for texture copy
set(TEXTURES_SOURCE_DIR "${CMAKE_SOURCE_DIR}/textures")
set(TEXTURES_DEST_DIR "${CMAKE_BINARY_DIR}/textures")

# Custom target to copy texture folder recursively
add_custom_target(copy_textures ALL
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${TEXTURES_SOURCE_DIR}"
        "${TEXTURES_DEST_DIR}"
        COMMENT "Copying textures directory to build folder"
)

# Make sure your executable depends on copying textures
add_dependencies(zerosu copy_textures)

# Paths for maps copy
set(MAPS_SOURCE_DIR "${CMAKE_SOURCE_DIR}/src/Osu/Maps")
set(MAPS_DEST_DIR "${CMAKE_BINARY_DIR}/Maps")

# Custom target to copy maps folder recursively
add_custom_target(copy_maps ALL
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${MAPS_SOURCE_DIR}"
        "${MAPS_DEST_DIR}"
        COMMENT "Copying maps directory to build folder"
)

# Make sure your executable depends on copying maps
add_dependencies(zerosu copy_maps)

# Paths for maps copy
set(SKINS_SOURCE_DIR "${CMAKE_SOURCE_DIR}/src/Osu/Skins")
set(SKINS_DEST_DIR "${CMAKE_BINARY_DIR}/Skins")

# Custom target to copy maps folder recursively
add_custom_target(copy_skins ALL
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${SKINS_SOURCE_DIR}"
        "${SKINS_DEST_DIR}"
        COMMENT "Copying skins directory to build folder"
)

# Make sure your executable depends on copying maps
add_dependencies(zerosu copy_skins)

# ===== BASS LIBRARY SETUP =====

# Detect OS and normalize
string(TOLOWER "${CMAKE_SYSTEM_NAME}" BASS_OS)
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" BASS_ARCH)
message("MY_VAR is: ${BASS_ARCH}")
# Normalize architecture names based on OS
if(WIN32)
    if(BASS_ARCH STREQUAL "amd64" OR BASS_ARCH STREQUAL "x86_64")
        set(BASS_ARCH "x64")
    elseif(BASS_ARCH MATCHES "^(i[3-6]86|x86)$")
        set(BASS_ARCH "x86")
    endif()
elseif(APPLE)
    if(BASS_ARCH MATCHES "aarch64")
        set(BASS_ARCH "aarch64")
    elseif(BASS_ARCH MATCHES "armv7l")
        set(BASS_ARCH "armhf")
    endif()
else()  # Linux/Unix
    if(BASS_ARCH STREQUAL "x86_64")
        set(BASS_ARCH "x86_64")
    elseif(BASS_ARCH MATCHES "aarch64")
        set(BASS_ARCH "aarch64")
    elseif(BASS_ARCH MATCHES "armv7l")
        set(BASS_ARCH "armhf")
    endif()
endif()

# Full path to BASS libs (now uses corrected architecture names)
set(BASS_PATH "${CMAKE_SOURCE_DIR}/libs/${BASS_OS}/${BASS_ARCH}")

# Set runtime and link library based on platform
if(WIN32)
    set(BASS_LINK_LIB "${BASS_PATH}/bass.lib")
elseif(APPLE)
    set(BASS_LINK_LIB "${BASS_PATH}/libbass.dylib")
elseif(UNIX)
    set(BASS_LINK_LIB "${BASS_PATH}/libbass.so")
endif()

# Include BASS headers (uncomment if you have headers)
# include_directories("${CMAKE_SOURCE_DIR}/include")
# Link the library
target_link_libraries(zerosu PRIVATE "${BASS_LINK_LIB}")