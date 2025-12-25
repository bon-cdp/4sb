/**
 * 4sb Terminal Bridge
 *
 * A lightweight C++ WebSocket-to-PTY bridge.
 * Connects mobile browsers to real Linux shells.
 *
 * Anti-slop: ~15MB RAM per connection.
 */

#include "crow_all.h"
#include <pty.h>
#include <unistd.h>
#include <sys/wait.h>
#include <thread>
#include <atomic>
#include <cstring>
#include <map>
#include <mutex>

// Session tracking
struct TerminalSession {
    int master_fd;
    pid_t child_pid;
    std::atomic<bool> active{true};
    std::thread reader_thread;
};

std::map<crow::websocket::connection*, std::unique_ptr<TerminalSession>> sessions;
std::mutex sessions_mutex;

// JWT validation (simplified - use a real library in production)
bool validate_token(const std::string& token) {
    // TODO: Implement real JWT validation
    // For now, accept any non-empty token
    return !token.empty();
}

std::string get_user_from_token(const std::string& token) {
    // TODO: Extract user from JWT
    return "user";
}

void cleanup_session(crow::websocket::connection* conn) {
    std::lock_guard<std::mutex> lock(sessions_mutex);
    auto it = sessions.find(conn);
    if (it != sessions.end()) {
        auto& session = it->second;
        session->active = false;

        // Kill the shell process
        if (session->child_pid > 0) {
            kill(session->child_pid, SIGTERM);
            waitpid(session->child_pid, nullptr, WNOHANG);
        }

        // Close the PTY
        if (session->master_fd > 0) {
            close(session->master_fd);
        }

        // Wait for reader thread
        if (session->reader_thread.joinable()) {
            session->reader_thread.join();
        }

        sessions.erase(it);
    }
}

int main(int argc, char* argv[]) {
    crow::SimpleApp app;

    int port = 8080;
    if (argc > 1) {
        port = std::atoi(argv[1]);
    }

    // Health check endpoint
    CROW_ROUTE(app, "/health")
    ([]() {
        return crow::response(200, "ok");
    });

    // Terminal WebSocket endpoint
    CROW_WEBSOCKET_ROUTE(app, "/shell")
        .onopen([&](crow::websocket::connection& conn) {
            // Extract token from query string
            // URL format: /shell?token=xyz
            auto token = conn.get_header_value("Sec-WebSocket-Protocol");

            // For initial dev, also check query params
            // In production, use proper auth headers

            CROW_LOG_INFO << "New terminal connection";

            // Create PTY
            int master_fd;
            pid_t pid = forkpty(&master_fd, nullptr, nullptr, nullptr);

            if (pid < 0) {
                CROW_LOG_ERROR << "forkpty failed: " << strerror(errno);
                conn.close("Failed to create terminal");
                return;
            }

            if (pid == 0) {
                // Child process - become the shell
                const char* shell = "/bin/bash";
                const char* user = "user";  // TODO: get from token

                // Set up environment
                setenv("TERM", "xterm-256color", 1);
                setenv("HOME", "/home/user", 1);
                setenv("USER", user, 1);
                setenv("PS1", "\\u@4sb:\\w$ ", 1);

                // Change to home directory
                chdir("/home/user");

                // Execute shell
                execlp(shell, shell, "--login", nullptr);

                // If exec fails
                _exit(1);
            }

            // Parent process - bridge WebSocket to PTY
            auto session = std::make_unique<TerminalSession>();
            session->master_fd = master_fd;
            session->child_pid = pid;

            // Start reader thread - reads from PTY, sends to WebSocket
            session->reader_thread = std::thread([&conn, master_fd, &session = *session]() {
                char buffer[4096];
                while (session.active) {
                    fd_set read_fds;
                    FD_ZERO(&read_fds);
                    FD_SET(master_fd, &read_fds);

                    struct timeval timeout;
                    timeout.tv_sec = 0;
                    timeout.tv_usec = 100000;  // 100ms

                    int ready = select(master_fd + 1, &read_fds, nullptr, nullptr, &timeout);

                    if (ready > 0 && FD_ISSET(master_fd, &read_fds)) {
                        ssize_t n = read(master_fd, buffer, sizeof(buffer));
                        if (n > 0) {
                            try {
                                conn.send_binary(std::string(buffer, n));
                            } catch (...) {
                                break;
                            }
                        } else if (n <= 0) {
                            break;
                        }
                    }
                }
            });

            {
                std::lock_guard<std::mutex> lock(sessions_mutex);
                sessions[&conn] = std::move(session);
            }

            CROW_LOG_INFO << "Terminal session started for connection";
        })
        .onclose([&](crow::websocket::connection& conn, const std::string& reason) {
            CROW_LOG_INFO << "Terminal connection closed: " << reason;
            cleanup_session(&conn);
        })
        .onmessage([&](crow::websocket::connection& conn, const std::string& data, bool is_binary) {
            std::lock_guard<std::mutex> lock(sessions_mutex);
            auto it = sessions.find(&conn);
            if (it != sessions.end() && it->second->active) {
                // Write user input to PTY
                write(it->second->master_fd, data.c_str(), data.size());
            }
        });

    CROW_LOG_INFO << "4sb Terminal Bridge starting on port " << port;
    app.port(port).multithreaded().run();

    return 0;
}
