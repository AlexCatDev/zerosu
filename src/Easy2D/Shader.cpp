#pragma once
#include "GLObject.cpp"
#include "Log.cpp"
#include <GLES2/gl2.h>
#include <fstream>
#include "../../include/glm/glm.hpp"
#include <map>

class Shader : public GLObject
{
private:
	const char* vertexFilename;
	const char* fragmentFilename;

	std::map<std::string, GLint> uniformLocationCache;

public:
	Shader(const char* vertexFilename, const char* fragmentFilename) {
		this->vertexFilename = vertexFilename;
		this->fragmentFilename = fragmentFilename;
	}

	void SetMatrix(const char* uniformName, glm::mat4& matrix, bool transpose = false) {
		glUniformMatrix4fv(getLocation(uniformName), 1, transpose, &matrix[0][0]);
	}

	void SetFloat(const char* uniformName, float value) {
		glUniform1f(getLocation(uniformName), value);
	}

	void SetInt(const char* uniformName, int32_t value) {
		glUniform1i(getLocation(uniformName), value);
	}

	void SetIntArray(const char* uniformName, const int* arr, int length) {
		glUniform1iv(getLocation(uniformName), length, arr);
	}

private:
	GLint getLocation(const char* name) {
		std::string lol(name);
		auto location = uniformLocationCache.find(lol);

		if (location == uniformLocationCache.end()) {
			auto uniform = glGetUniformLocation(handle, name);

			Log(name, LogLevel::Info);

			if (uniform == -1) {
				Log("Uniform was not found!", LogLevel::Error);
			}

			Log("Uniform location was not cached, caching..", LogLevel::Info);

			uniformLocationCache.insert(std::pair<std::string, GLint>(lol, uniform));

			return uniform;
		}

		return location->second;
	}

	void parseAndAttachShader(const char* filename, GLenum shaderType) {

		auto shaderID = glCreateShader(shaderType);

		if (shaderID == 0) {
			Log("Could not create shader", LogLevel::Error);
		}

		std::ifstream file(filename, std::ios::in | std::ios::binary);
		std::string result;

		if (file) {
			file.seekg(0, std::ios::end);
			result.resize(file.tellg());
			file.seekg(0, std::ios::beg);
			file.read(&result[0], result.size());
			file.close();
		}
		else {
			Log("Failed to open shader file", LogLevel::Error);
			return;
		}

		const GLchar* sourceCStr = result.c_str();
		glShaderSource(shaderID, 1, &sourceCStr, 0);

		glCompileShader(shaderID);

		GLint didCompile = 0;
		glGetShaderiv(shaderID, GL_COMPILE_STATUS, &didCompile);

		if (didCompile == GL_FALSE) {
				char buffer[512];
				glGetShaderInfoLog(shaderID, sizeof(buffer), nullptr, buffer);
				std::cerr << "Shader compile error: " << buffer << std::endl;

			Log("Failed to compile!", LogLevel::Error);
		}

		//get shader log LOL
		glAttachShader(handle, shaderID);

		glLinkProgram(handle);

		glGetShaderiv(handle, GL_LINK_STATUS, &didCompile);
		if (didCompile == GL_FALSE) {
			Log("Failed to link!", LogLevel::Error);
		}
	}

	void bind(int slot = 0) override {
		glUseProgram(handle);
	}

	void initialize() override {
		handle = glCreateProgram();

		if (handle == 0) {
			Log("Error creating program, handle was 0", LogLevel::Error);
			return;
		}

		Log("Parsing Vertex Shader", LogLevel::Info);
		parseAndAttachShader(vertexFilename, GL_VERTEX_SHADER);

		Log("Parsing Fragment Shader", LogLevel::Info);
		parseAndAttachShader(fragmentFilename, GL_FRAGMENT_SHADER);
	}

	void release() override {
		glDeleteProgram(handle);
		handle = UninitializedHandle;
	}
};