/**
 * @file avionics_display.h
 * @brief OpenGL-based avionics display system for Intel SOM platforms
 * @author Avionics Embedded Expert
 * @version 1.0
 * @date 2024
 * 
 * This implementation provides a foundation for developing OpenGL-based
 * avionics displays compatible with Intel SOM 2533 and Advantech SOM-DB2510
 * platforms with Alder Lake-N UHD GPU support.
 */

#ifndef AVIONICS_DISPLAY_H
#define AVIONICS_DISPLAY_H

#include <GL/gl.h>
#include <GL/glext.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <cstdint>
#include <memory>
#include <vector>

namespace avionics {

/**
 * @class DisplayManager
 * @brief Manages OpenGL context and rendering for avionics displays
 */
class DisplayManager {
public:
    struct DisplayConfig {
        uint32_t width;
        uint32_t height;
        uint32_t refresh_rate;
        bool vsync_enabled;
        bool multisampling;
        uint32_t samples;
    };

    struct RenderStats {
        float frame_time_ms;
        float gpu_utilization;
        uint32_t frames_rendered;
        uint32_t dropped_frames;
    };

    DisplayManager();
    ~DisplayManager();

    /**
     * @brief Initialize the display system
     * @param config Display configuration parameters
     * @return true if initialization successful, false otherwise
     */
    bool initialize(const DisplayConfig& config);

    /**
     * @brief Create OpenGL context for the display
     * @return true if context creation successful
     */
    bool createContext();

    /**
     * @brief Begin frame rendering
     */
    void beginFrame();

    /**
     * @brief End frame rendering and swap buffers
     */
    void endFrame();

    /**
     * @brief Get current rendering statistics
     * @return RenderStats structure with performance metrics
     */
    RenderStats getRenderStats() const;

    /**
     * @brief Check if display is ready for rendering
     * @return true if ready, false otherwise
     */
    bool isReady() const { return context_ready_; }

    /**
     * @brief Clean up resources
     */
    void cleanup();

private:
    EGLDisplay egl_display_;
    EGLContext egl_context_;
    EGLSurface egl_surface_;
    EGLConfig egl_config_;
    
    DisplayConfig config_;
    bool context_ready_;
    bool vsync_enabled_;
    
    // Performance monitoring
    mutable RenderStats stats_;
    uint64_t frame_start_time_;
    uint32_t frame_counter_;
    
    bool setupEGL();
    bool chooseEGLConfig();
    void updateStats();
};

/**
 * @class AvionicsRenderer
 * @brief High-level rendering system for avionics graphics
 */
class AvionicsRenderer {
public:
    enum class PrimitiveType {
        LINES,
        TRIANGLES,
        QUADS,
        POINTS
    };

    struct Vertex {
        float x, y, z;        // Position
        float r, g, b, a;     // Color
        float u, v;           // Texture coordinates
    };

    struct RenderObject {
        std::vector<Vertex> vertices;
        std::vector<uint32_t> indices;
        PrimitiveType type;
        uint32_t texture_id;
        bool visible;
    };

    AvionicsRenderer(std::shared_ptr<DisplayManager> display);
    ~AvionicsRenderer();

    /**
     * @brief Initialize renderer resources
     * @return true if successful
     */
    bool initialize();

    /**
     * @brief Create a render object
     * @param vertices Vertex data
     * @param indices Index data
     * @param type Primitive type
     * @return Object ID for future reference
     */
    uint32_t createRenderObject(const std::vector<Vertex>& vertices,
                               const std::vector<uint32_t>& indices,
                               PrimitiveType type);

    /**
     * @brief Load texture from memory
     * @param data Raw image data
     * @param width Image width
     * @param height Image height
     * @param format Pixel format (GL_RGB, GL_RGBA, etc.)
     * @return Texture ID
     */
    uint32_t loadTexture(const uint8_t* data, uint32_t width, 
                        uint32_t height, GLenum format);

    /**
     * @brief Set projection matrix
     * @param fov Field of view in degrees
     * @param aspect Aspect ratio
     * @param near_plane Near clipping plane
     * @param far_plane Far clipping plane
     */
    void setPerspectiveProjection(float fov, float aspect, 
                                 float near_plane, float far_plane);

    /**
     * @brief Set orthographic projection
     * @param left Left bound
     * @param right Right bound
     * @param bottom Bottom bound
     * @param top Top bound
     * @param near_plane Near clipping plane
     * @param far_plane Far clipping plane
     */
    void setOrthographicProjection(float left, float right, 
                                  float bottom, float top,
                                  float near_plane, float far_plane);

    /**
     * @brief Render all visible objects
     */
    void render();

    /**
     * @brief Clear framebuffer
     * @param r Red component (0.0-1.0)
     * @param g Green component (0.0-1.0)
     * @param b Blue component (0.0-1.0)
     * @param a Alpha component (0.0-1.0)
     */
    void clear(float r = 0.0f, float g = 0.0f, float b = 0.0f, float a = 1.0f);

private:
    std::shared_ptr<DisplayManager> display_;
    std::vector<RenderObject> render_objects_;
    
    uint32_t shader_program_;
    uint32_t vao_;
    uint32_t vbo_;
    uint32_t ebo_;
    
    float projection_matrix_[16];
    float view_matrix_[16];
    
    bool compileShaders();
    bool setupBuffers();
    void updateMatrices();
};

/**
 * @class AvionicsHUD
 * @brief Heads-up display system for avionics applications
 */
class AvionicsHUD {
public:
    struct HUDElement {
        enum Type {
            TEXT,
            LINE,
            CIRCLE,
            RECTANGLE,
            CROSSHAIR,
            ALTITUDE_LADDER,
            ATTITUDE_INDICATOR
        };
        
        Type type;
        float x, y;           // Position (normalized coordinates)
        float width, height;  // Size
        float rotation;       // Rotation in degrees
        uint32_t color;       // RGBA color
        std::string text;     // For text elements
        bool visible;
    };

    AvionicsHUD(std::shared_ptr<AvionicsRenderer> renderer);
    ~AvionicsHUD();

    /**
     * @brief Initialize HUD system
     * @return true if successful
     */
    bool initialize();

    /**
     * @brief Add HUD element
     * @param element Element to add
     * @return Element ID
     */
    uint32_t addElement(const HUDElement& element);

    /**
     * @brief Update element properties
     * @param id Element ID
     * @param element New element data
     */
    void updateElement(uint32_t id, const HUDElement& element);

    /**
     * @brief Remove element
     * @param id Element ID
     */
    void removeElement(uint32_t id);

    /**
     * @brief Render all HUD elements
     */
    void render();

    /**
     * @brief Set HUD visibility
     * @param visible Visibility state
     */
    void setVisible(bool visible) { visible_ = visible; }

private:
    std::shared_ptr<AvionicsRenderer> renderer_;
    std::vector<HUDElement> elements_;
    uint32_t next_id_;
    bool visible_;
    
    void renderText(const HUDElement& element);
    void renderLine(const HUDElement& element);
    void renderCircle(const HUDElement& element);
    void renderRectangle(const HUDElement& element);
    void renderCrosshair(const HUDElement& element);
    void renderAltitudeLadder(const HUDElement& element);
    void renderAttitudeIndicator(const HUDElement& element);
};

} // namespace avionics

#endif // AVIONICS_DISPLAY_H