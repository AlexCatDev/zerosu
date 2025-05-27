#ifndef VIEWPORT_H
#define VIEWPORT_H
#include <GLES2/gl2.h>
#include "../../include/glm/glm.hpp"

class Viewport {
private:
	static int x, y, width, height;
public:
	Viewport() = delete;
	
	static void Set(int x, int y, int width, int height) {
		glScissor(x, y, width, height);
		glViewport(x, y, width, height);

		Viewport::x = x;
		Viewport::y = y;
		Viewport::width = width;
		Viewport::height = height;

		//printf("Set Viewport: (%d, %d) (%d, %d)\n", x, y, width, height);
	}

	static int GetHeight() { return Viewport::height; }
	static int GetWidth() { return Viewport::width; }
	static int GetY() { return Viewport::y; }
	static int GetX() { return Viewport::x; }

	static glm::ivec2 GetSize() { return {Viewport::width, Viewport::height}; }
	static glm::ivec2 GetPosition() { return {Viewport::x, Viewport::y}; }
};

#endif //VIEWPORT_H
