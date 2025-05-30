#pragma once

/*
Foreground Colors (Text Color):
    Bright Black: \u001b[30;1m
    Bright Red: \u001b[31;1m
    Bright Green: \u001b[32;1m
    Bright Yellow: \u001b[33;1m
    Bright Blue: \u001b[34;1m
    Bright Magenta: \u001b[35;1m
    Bright Cyan: \u001b[36;1m
    Bright White: \u001b[37;1m
    Reset: \u001b[0m

Background Colors:
    Background Black: \u001b[40m
    Background Red: \u001b[41m
    Background Green: \u001b[42m
    Background Yellow: \u001b[43m
    Background Blue: \u001b[44m
    Background Magenta: \u001b[45m
    Background Cyan: \u001b[46m
    Background White: \u001b[47m

With the bright versions being:
    Background Bright Black: \u001b[40;1m
    Background Bright Red: \u001b[41;1m
    Background Bright Green: \u001b[42;1m
    Background Bright Yellow: \u001b[43;1m
    Background Bright Blue: \u001b[44;1m
    Background Bright Magenta: \u001b[45;1m
    Background Bright Cyan: \u001b[46;1m
    Background Bright White: \u001b[47;1m
*/

#include <iostream>
#include <chrono>
#include <ctime>

#if defined(_WIN32)
#include <windows.h>
#endif

enum LogLevel {
    Info,
    Warning,
    Error
};

static void EnableVirtualTerminalColors() {
#if defined(_WIN32)
    static bool enabled = false;
    if (!enabled) {
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        if (hOut != INVALID_HANDLE_VALUE) {
            DWORD dwMode = 0;
            if (GetConsoleMode(hOut, &dwMode)) {
                dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
                SetConsoleMode(hOut, dwMode);
                enabled = true;
            }
        }
    }
#endif
}

static void Log(const char* message, LogLevel level = LogLevel::Info) {
    EnableVirtualTerminalColors(); // Do nothing on Linux/macOS

    auto now = std::chrono::system_clock::now();
    auto nowTime = std::chrono::system_clock::to_time_t(now);

    char timeString[26];

#if defined(_WIN32)
    ctime_s(timeString, sizeof(timeString), &nowTime);
#else
    std::strftime(timeString, sizeof(timeString), "%Y-%m-%d %H:%M:%S", std::localtime(&nowTime));
#endif

    // Optional trim newline if using std::ctime directly
    // timeString[std::strlen(timeString) - 1] = '\0';

    switch (level) {
        case Info:
            std::cout << timeString << " [\u001b[36mINFO\u001b[0m] " << message << std::endl;
            break;
        case Warning:
            std::cout << timeString << " [\u001b[33mWARN\u001b[0m] " << message << std::endl;
            break;
        case Error:
            std::cout << timeString << " [\u001b[31mERROR\u001b[0m] " << message << std::endl;
            break;
        default:
            break;
    }
}