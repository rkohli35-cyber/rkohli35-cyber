/**
 * @file rt_scheduler.h
 * @brief Real-time task scheduler for avionics applications
 * @author Avionics Embedded Expert
 * @version 1.0
 * @date 2024
 * 
 * Provides deterministic real-time scheduling capabilities for safety-critical
 * avionics applications running on Linux with PREEMPT_RT patches.
 */

#ifndef RT_SCHEDULER_H
#define RT_SCHEDULER_H

#include <pthread.h>
#include <sched.h>
#include <time.h>
#include <atomic>
#include <vector>
#include <memory>
#include <functional>

namespace avionics {

/**
 * @class RealTimeTask
 * @brief Represents a real-time task with scheduling parameters
 */
class RealTimeTask {
public:
    enum class Priority {
        CRITICAL = 99,      // Highest priority for safety-critical tasks
        HIGH = 80,          // High priority for time-sensitive operations
        MEDIUM = 50,        // Medium priority for normal operations
        LOW = 20,           // Low priority for background tasks
        IDLE = 1            // Lowest priority for non-critical tasks
    };

    enum class SchedulingPolicy {
        FIFO = SCHED_FIFO,
        RR = SCHED_RR,
        DEADLINE = SCHED_DEADLINE
    };

    struct TaskConfig {
        std::string name;
        Priority priority;
        SchedulingPolicy policy;
        uint64_t period_ns;         // Task period in nanoseconds
        uint64_t deadline_ns;       // Task deadline in nanoseconds
        uint64_t runtime_ns;        // Expected runtime in nanoseconds
        size_t stack_size;          // Stack size in bytes
        int cpu_affinity;           // CPU core affinity (-1 for any)
        bool memory_lock;           // Lock memory to prevent swapping
    };

    struct TaskStats {
        uint64_t executions;
        uint64_t missed_deadlines;
        uint64_t max_execution_time_ns;
        uint64_t min_execution_time_ns;
        uint64_t avg_execution_time_ns;
        double cpu_utilization;
    };

    using TaskFunction = std::function<void()>;

    RealTimeTask(const TaskConfig& config, TaskFunction task_func);
    ~RealTimeTask();

    /**
     * @brief Start the real-time task
     * @return true if task started successfully
     */
    bool start();

    /**
     * @brief Stop the real-time task
     */
    void stop();

    /**
     * @brief Check if task is running
     * @return true if running, false otherwise
     */
    bool isRunning() const { return running_.load(); }

    /**
     * @brief Get task statistics
     * @return TaskStats structure with performance metrics
     */
    TaskStats getStats() const;

    /**
     * @brief Reset task statistics
     */
    void resetStats();

    /**
     * @brief Get task configuration
     * @return TaskConfig structure
     */
    const TaskConfig& getConfig() const { return config_; }

private:
    TaskConfig config_;
    TaskFunction task_func_;
    pthread_t thread_;
    std::atomic<bool> running_;
    std::atomic<bool> stop_requested_;
    
    mutable TaskStats stats_;
    struct timespec next_period_;
    
    static void* taskWrapper(void* arg);
    void taskLoop();
    bool setupRealTimeProperties();
    void updateStats(uint64_t execution_time_ns);
    void waitForNextPeriod();
};

/**
 * @class RealTimeScheduler
 * @brief Manages multiple real-time tasks with priority scheduling
 */
class RealTimeScheduler {
public:
    struct SchedulerConfig {
        bool enable_cpu_isolation;      // Isolate CPUs for real-time tasks
        bool disable_irq_balancing;     // Disable IRQ balancing on RT CPUs
        bool set_cpu_governor;          // Set CPU governor to performance
        int rt_cpu_mask;                // Bitmask of CPUs for RT tasks
        size_t max_tasks;               // Maximum number of tasks
    };

    RealTimeScheduler();
    ~RealTimeScheduler();

    /**
     * @brief Initialize the scheduler
     * @param config Scheduler configuration
     * @return true if initialization successful
     */
    bool initialize(const SchedulerConfig& config);

    /**
     * @brief Add a real-time task
     * @param task Shared pointer to the task
     * @return Task ID for future reference
     */
    uint32_t addTask(std::shared_ptr<RealTimeTask> task);

    /**
     * @brief Remove a task
     * @param task_id Task ID to remove
     * @return true if task was removed successfully
     */
    bool removeTask(uint32_t task_id);

    /**
     * @brief Start all tasks
     * @return true if all tasks started successfully
     */
    bool startAllTasks();

    /**
     * @brief Stop all tasks
     */
    void stopAllTasks();

    /**
     * @brief Start specific task
     * @param task_id Task ID to start
     * @return true if task started successfully
     */
    bool startTask(uint32_t task_id);

    /**
     * @brief Stop specific task
     * @param task_id Task ID to stop
     */
    void stopTask(uint32_t task_id);

    /**
     * @brief Get scheduler statistics
     * @return Vector of task statistics
     */
    std::vector<RealTimeTask::TaskStats> getStatistics() const;

    /**
     * @brief Check system real-time capabilities
     * @return true if system supports real-time scheduling
     */
    static bool checkRealTimeSupport();

    /**
     * @brief Configure system for optimal real-time performance
     * @return true if configuration successful
     */
    static bool configureSystemForRealTime();

private:
    SchedulerConfig config_;
    std::vector<std::shared_ptr<RealTimeTask>> tasks_;
    uint32_t next_task_id_;
    bool initialized_;
    
    bool setupCpuIsolation();
    bool configureCpuGovernor();
    bool disableIrqBalancing();
    bool validateTaskSet() const;
};

/**
 * @class InterTaskCommunication
 * @brief Provides lock-free communication mechanisms for real-time tasks
 */
class InterTaskCommunication {
public:
    /**
     * @class LockFreeQueue
     * @brief Single-producer, single-consumer lock-free queue
     */
    template<typename T, size_t SIZE>
    class LockFreeQueue {
    public:
        LockFreeQueue() : head_(0), tail_(0) {}

        /**
         * @brief Push element to queue (producer side)
         * @param item Item to push
         * @return true if successful, false if queue is full
         */
        bool push(const T& item) {
            size_t head = head_.load(std::memory_order_relaxed);
            size_t next_head = (head + 1) % SIZE;
            
            if (next_head == tail_.load(std::memory_order_acquire)) {
                return false; // Queue is full
            }
            
            buffer_[head] = item;
            head_.store(next_head, std::memory_order_release);
            return true;
        }

        /**
         * @brief Pop element from queue (consumer side)
         * @param item Reference to store popped item
         * @return true if successful, false if queue is empty
         */
        bool pop(T& item) {
            size_t tail = tail_.load(std::memory_order_relaxed);
            
            if (tail == head_.load(std::memory_order_acquire)) {
                return false; // Queue is empty
            }
            
            item = buffer_[tail];
            tail_.store((tail + 1) % SIZE, std::memory_order_release);
            return true;
        }

        /**
         * @brief Check if queue is empty
         * @return true if empty
         */
        bool empty() const {
            return tail_.load(std::memory_order_acquire) == 
                   head_.load(std::memory_order_acquire);
        }

        /**
         * @brief Get current queue size
         * @return Number of elements in queue
         */
        size_t size() const {
            size_t head = head_.load(std::memory_order_acquire);
            size_t tail = tail_.load(std::memory_order_acquire);
            return (head >= tail) ? (head - tail) : (SIZE - tail + head);
        }

    private:
        alignas(64) std::atomic<size_t> head_;  // Producer index
        alignas(64) std::atomic<size_t> tail_;  // Consumer index
        T buffer_[SIZE];
    };

    /**
     * @class SharedMemoryPool
     * @brief Lock-free memory pool for inter-task communication
     */
    template<size_t BLOCK_SIZE, size_t NUM_BLOCKS>
    class SharedMemoryPool {
    public:
        SharedMemoryPool() : free_list_(0) {
            // Initialize free list
            for (size_t i = 0; i < NUM_BLOCKS - 1; ++i) {
                *reinterpret_cast<size_t*>(&pool_[i * BLOCK_SIZE]) = i + 1;
            }
            *reinterpret_cast<size_t*>(&pool_[(NUM_BLOCKS - 1) * BLOCK_SIZE]) = NUM_BLOCKS;
        }

        /**
         * @brief Allocate a memory block
         * @return Pointer to allocated block, nullptr if pool is empty
         */
        void* allocate() {
            size_t old_head = free_list_.load(std::memory_order_relaxed);
            
            while (old_head != NUM_BLOCKS) {
                size_t new_head = *reinterpret_cast<size_t*>(&pool_[old_head * BLOCK_SIZE]);
                
                if (free_list_.compare_exchange_weak(old_head, new_head,
                                                   std::memory_order_release,
                                                   std::memory_order_relaxed)) {
                    return &pool_[old_head * BLOCK_SIZE];
                }
            }
            
            return nullptr; // Pool is empty
        }

        /**
         * @brief Deallocate a memory block
         * @param ptr Pointer to block to deallocate
         */
        void deallocate(void* ptr) {
            if (!ptr) return;
            
            size_t index = (static_cast<char*>(ptr) - pool_) / BLOCK_SIZE;
            if (index >= NUM_BLOCKS) return; // Invalid pointer
            
            size_t old_head = free_list_.load(std::memory_order_relaxed);
            do {
                *reinterpret_cast<size_t*>(ptr) = old_head;
            } while (!free_list_.compare_exchange_weak(old_head, index,
                                                     std::memory_order_release,
                                                     std::memory_order_relaxed));
        }

    private:
        alignas(64) std::atomic<size_t> free_list_;
        char pool_[NUM_BLOCKS * BLOCK_SIZE];
    };
};

} // namespace avionics

#endif // RT_SCHEDULER_H