#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <csignal>
#include <random>
#include <thread>
#include <mutex>
#include <map>
#include <fstream>
#include <numeric>
#include <algorithm>

// --- Configuration ---
const int NUM_WORKER_CHILDREN = 5;
const int NUM_AGGREGATOR_THREADS = 3;
const size_t BUFFER_SIZE = 1024;
const int WRITES_PER_WORKER = 50;
const char* FILE_PREFIX = "/tmp/pgo_benchmark_";

// --- Global Variables & Utilities ---
std::mutex g_summaryMutex;

// A simple signal handler
void handle_signal(int signum) {
    // Using a non-async-safe function like cout here is generally bad practice,
    // but it's acceptable for this benchmark to see if Valgrind catches it.
    std::cout << "\n[PID " << getpid() << "] Caught signal " << signum << ". Shutting down." << std::endl;
}

// Generates a block of random data
void generate_random_data(char* buffer, size_t size) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> distrib(0, 255);
    for (size_t i = 0; i < size; ++i) {
        buffer[i] = static_cast<char>(distrib(gen));
    }
}

// Calculates a simple checksum
uint32_t calculate_checksum(const char* buffer, size_t size) {
    uint32_t checksum = 0;
    for (size_t i = 0; i < size; ++i) {
        checksum = (checksum << 5) + checksum + buffer[i];
    }
    return checksum;
}

// --- Worker Process Logic ---
void run_worker_process(int worker_id, bool should_leak) {
    std::cout << "[Worker " << worker_id << " | PID " << getpid() << "] Starting." << std::endl;
    std::string filename = std::string(FILE_PREFIX) + std::to_string(worker_id) + ".dat";
    
    // Open a file using a low-level file descriptor
    int fd = open(filename.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        perror("Failed to open file in worker");
        exit(EXIT_FAILURE);
    }

    char* data_buffer = new char[BUFFER_SIZE];
    uint32_t total_checksum = 0;

    for (int i = 0; i < WRITES_PER_WORKER; ++i) {
        generate_random_data(data_buffer, BUFFER_SIZE);
        ssize_t bytes_written = write(fd, data_buffer, BUFFER_SIZE);
        if (bytes_written != BUFFER_SIZE) {
            perror("Worker failed to write all bytes");
            break;
        }
        total_checksum += calculate_checksum(data_buffer, BUFFER_SIZE);
    }
    
    std::cout << "[Worker " << worker_id << "] Wrote " << WRITES_PER_WORKER << " blocks. Total checksum: " << total_checksum << std::endl;
    
    close(fd);
    
    // Intentionally leak memory based on a condition to give PGO something to learn
    if (should_leak) {
        std::cout << "[Worker " << worker_id << "] Intentionally leaking memory." << std::endl;
        // This memory is never freed
        char* leaked_memory = (char*)malloc(128 * worker_id + 64);
        strcpy(leaked_memory, "This is a deliberate memory leak.");
    } else {
        // This path correctly frees the memory
        delete[] data_buffer;
    }
    
    exit(EXIT_SUCCESS);
}

// --- Aggregator Process Logic ---

// Task for each aggregator thread
void aggregate_files_task(int thread_id, const std::vector<std::string>& files, std::map<std::string, uint32_t>& summary) {
    char read_buffer[BUFFER_SIZE];
    for (const auto& filename : files) {
        std::ifstream infile(filename, std::ios::binary);
        if (!infile.is_open()) {
            std::cerr << "[Aggregator Thread " << thread_id << "] Failed to open " << filename << std::endl;
            continue;
        }

        uint32_t file_checksum = 0;
        while (infile.read(read_buffer, BUFFER_SIZE)) {
            file_checksum += calculate_checksum(read_buffer, infile.gcount());
        }
        // Handle last partial read
        if (infile.gcount() > 0) {
            file_checksum += calculate_checksum(read_buffer, infile.gcount());
        }

        // Lock the mutex to safely update the shared map
        std::lock_guard<std::mutex> lock(g_summaryMutex);
        summary[filename] = file_checksum;
        std::cout << "[Aggregator Thread " << thread_id << "] Processed " << filename << " -> Checksum: " << file_checksum << std::endl;
    }
}

void run_aggregator_process() {
    std::cout << "[Aggregator | PID " << getpid() << "] Starting. Waiting for worker files..." << std::endl;
    sleep(1); // Give workers time to create files

    std::vector<std::string> worker_files;
    for (int i = 0; i < NUM_WORKER_CHILDREN; ++i) {
        worker_files.push_back(std::string(FILE_PREFIX) + std::to_string(i) + ".dat");
    }

    std::map<std::string, uint32_t> summary_map;
    std::vector<std::thread> threads;
    std::vector<std::vector<std::string>> work_chunks(NUM_AGGREGATOR_THREADS);

    // Distribute files among threads
    for (size_t i = 0; i < worker_files.size(); ++i) {
        work_chunks[i % NUM_AGGREGATOR_THREADS].push_back(worker_files[i]);
    }

    std::cout << "[Aggregator] Launching " << NUM_AGGREGATOR_THREADS << " threads to process files." << std::endl;
    for (int i = 0; i < NUM_AGGREGATOR_THREADS; ++i) {
        threads.emplace_back(aggregate_files_task, i, work_chunks[i], std::ref(summary_map));
    }
    
    // Wait for all threads to finish
    for (auto& t : threads) {
        t.join();
    }
    
    std::cout << "[Aggregator] All threads finished. Writing summary report." << std::endl;

    // Write final summary
    std::string summary_filename = std::string(FILE_PREFIX) + "summary.txt";
    std::ofstream outfile(summary_filename);
    outfile << "--- PGO Benchmark Summary Report ---\n";
    for (const auto& pair : summary_map) {
        outfile << "File: " << pair.first << ", Checksum: " << pair.second << "\n";
    }
    outfile.close();

    std::cout << "[Aggregator] Summary written to " << summary_filename << std::endl;
    exit(EXIT_SUCCESS);
}

// --- Main Function ---
int main(int argc, char* argv[]) {
    signal(SIGINT, handle_signal);
    std::cout << "[Main | PID " << getpid() << "] Starting PGO benchmark." << std::endl;

    std::vector<pid_t> child_pids;
    
    // Fork worker children
    for (int i = 0; i < NUM_WORKER_CHILDREN; ++i) {
        pid_t pid = fork();
        if (pid == -1) {
            perror("Failed to fork worker");
            exit(EXIT_FAILURE);
        } else if (pid == 0) {
            // In child process: determine if this instance should leak memory
            // Let's make odd-numbered workers leak memory
            run_worker_process(i, (i % 2 != 0));
        } else {
            child_pids.push_back(pid);
        }
    }

    // Fork aggregator child
    pid_t aggregator_pid = fork();
    if (aggregator_pid == -1) {
        perror("Failed to fork aggregator");
        exit(EXIT_FAILURE);
    } else if (aggregator_pid == 0) {
        run_aggregator_process();
    } else {
        child_pids.push_back(aggregator_pid);
    }
    
    // Parent process waits for all children
    std::cout << "[Main] Waiting for " << child_pids.size() << " child processes..." << std::endl;
    int status;
    for (pid_t pid : child_pids) {
        if (waitpid(pid, &status, 0) == -1) {
            perror("waitpid failed");
        } else {
            if (WIFEXITED(status)) {
                std::cout << "[Main] Child PID " << pid << " exited with status " << WEXITSTATUS(status) << std::endl;
            } else {
                std::cout << "[Main] Child PID " << pid << " terminated abnormally." << std::endl;
            }
        }
    }

    // Cleanup
    std::cout << "[Main] Cleaning up generated files." << std::endl;
    for (int i = 0; i < NUM_WORKER_CHILDREN; ++i) {
        std::string filename = std::string(FILE_PREFIX) + std::to_string(i) + ".dat";
        remove(filename.c_str());
    }
    remove((std::string(FILE_PREFIX) + "summary.txt").c_str());

    std::cout << "[Main] Benchmark finished." << std::endl;
    return 0;
}
