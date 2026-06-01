#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

std::string trim(std::string value) {
    while (!value.empty() && (value.back() == '\n' || value.back() == '\r' || value.back() == ' ' || value.back() == '\t')) {
        value.pop_back();
    }
    std::size_t start = 0;
    while (start < value.size() && (value[start] == ' ' || value[start] == '\t')) {
        start++;
    }
    return value.substr(start);
}

std::string run(const std::string& command) {
    std::string output;
    FILE* pipe = popen((command + " 2>/dev/null").c_str(), "r");
    if (!pipe) {
        return output;
    }

    char buffer[256];
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        output += buffer;
    }
    pclose(pipe);
    return trim(output);
}

std::map<std::string, std::string> read_os_release() {
    std::map<std::string, std::string> values;
    std::ifstream file("/usr/lib/os-release");
    std::string line;

    while (std::getline(file, line)) {
        auto separator = line.find('=');
        if (separator == std::string::npos) {
            continue;
        }

        std::string key = line.substr(0, separator);
        std::string value = line.substr(separator + 1);
        if (value.size() >= 2 && value.front() == '"' && value.back() == '"') {
            value = value.substr(1, value.size() - 2);
        }
        values[key] = value;
    }

    return values;
}

bool command_exists(const std::string& command) {
    return std::system(("command -v " + command + " >/dev/null 2>&1").c_str()) == 0;
}

void print_help() {
    std::cout
        << "livioctl - Livio OS helper\n\n"
        << "Usage:\n"
        << "  livioctl status\n"
        << "  livioctl doctor\n"
        << "  livioctl graphics\n"
        << "  livioctl release\n";
}

int status() {
    auto release = read_os_release();
    std::cout << "Livio status\n";
    std::cout << "OS       " << (release.count("PRETTY_NAME") ? release["PRETTY_NAME"] : "unknown") << "\n";
    std::cout << "Kernel   " << run("uname -r") << "\n";
    std::cout << "Session  " << (std::getenv("XDG_SESSION_TYPE") ? std::getenv("XDG_SESSION_TYPE") : "unknown") << "\n";
    std::cout << "Desktop  " << (std::getenv("XDG_CURRENT_DESKTOP") ? std::getenv("XDG_CURRENT_DESKTOP") : "unknown") << "\n";
    if (command_exists("pacman")) {
        std::string kernels = run("pacman -Q linux-livio linux linux-lts");
        if (!kernels.empty()) {
            std::cout << "Kernels\n" << kernels << "\n";
        }
    }
    return 0;
}

int doctor() {
    struct Check {
        std::string name;
        bool ok;
    };

    std::vector<Check> checks = {
        {"Livio identity", fs::exists("/usr/lib/os-release")},
        {"Fastfetch config", fs::exists(fs::path(std::getenv("HOME") ? std::getenv("HOME") : "") / ".config/fastfetch/config.jsonc")},
        {"Fastfetch logo", fs::exists(fs::path(std::getenv("HOME") ? std::getenv("HOME") : "") / ".config/fastfetch/livio-logo.txt")},
        {"GPU helper", fs::exists("/usr/local/bin/livio-detect-gpu")},
        {"Heroic helper", fs::exists("/usr/local/bin/livio-install-heroic")},
        {"NetworkManager", command_exists("nmcli")},
        {"Flatpak", command_exists("flatpak")}
    };

    bool healthy = true;
    for (const auto& check : checks) {
        std::cout << (check.ok ? "[OK] " : "[!!] ") << check.name << "\n";
        healthy = healthy && check.ok;
    }

    return healthy ? 0 : 1;
}

int graphics() {
    if (fs::exists("/usr/local/bin/livio-detect-gpu")) {
        std::cout << run("/usr/local/bin/livio-detect-gpu") << "\n";
        return 0;
    }

    std::cout << "recommended=gpu-open\nGPU helper is not installed.\n";
    return 1;
}

int release() {
    auto values = read_os_release();
    for (const auto& key : {"PRETTY_NAME", "VERSION", "ID", "BUILD_ID", "LOGO"}) {
        if (values.count(key)) {
            std::cout << key << "=" << values[key] << "\n";
        }
    }
    return 0;
}

int main(int argc, char** argv) {
    std::string command = argc > 1 ? argv[1] : "help";

    if (command == "status") {
        return status();
    }
    if (command == "doctor") {
        return doctor();
    }
    if (command == "graphics") {
        return graphics();
    }
    if (command == "release") {
        return release();
    }

    print_help();
    return command == "help" || command == "--help" || command == "-h" ? 0 : 1;
}
