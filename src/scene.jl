
struct Camera
    view::Node{Mat4f0}
    projection::Node{Mat4f0}
    projectionview::Node{Mat4f0}
    resolution::Node{Vec2f0}
    eyeposition::Node{Vec3f0}
    steering_nodes::Vector{Node}
end
function disconnect!(c::Camera)
    for node in c.steering_nodes
        disconnect!(node)
    end
    empty!(c.steering_nodes)
    return
end

"""
When mapping over nodes for the camera, we store them in the steering_node vector,
to make it easier to disconnect the camera steering signals later!
"""
function Base.map(f, c::Camera, nodes::Node...)
    node = map(f, nodes...)
    push!(c.steering_nodes, node)
end

Camera(px_area) = Camera(
    Node(eye(Mat4f0)),
    Node(eye(Mat4f0)),
    Node(eye(Mat4f0)),
    map(a-> Vec2f0(widths(a)), px_area),
    Node(Vec3f0(1)),
    Node[]
)

struct Scene
    events::Events

    px_area::Node{IRect2D}
    camera::Camera

    limits::Node{HyperRectangle{3, Float32}}

    scale::Node{Vec3f0}
    flip::Node{NTuple{3, Bool}}

    plots::Vector{AbstractPlot}
    theme::Attributes
    children::Vector{Scene}
    current_screens::Vector{AbstractScreen}
end

function Base.push!(scene::Scene, plot::AbstractPlot)
    push!(scene.plots, plot)
    parent(plot)[] = scene
    for screen in scene.current_screens
        insert!(screen, scene, plot)
    end
end

const global_current_scene = Ref{Scene}()

current_scene() = global_current_scene[]

function Scene(area = nothing)
    events = Events()
    if area == nothing
        px_area = map(x-> IRect(0, 0, widths(x)), events.window_area)
    else
        px_area = signal_convert(Signal{IRect2D}, area)
    end
    scene = Scene(
        events,
        px_area,
        Camera(px_area),
        Signal(AABB(Vec3f0(0), Vec3f0(1))),
        Signal(Vec3f0(1)),
        Signal((false, false, false)),
        AbstractPlot[],
        Attributes(),
        Scene[],
        AbstractScreen[]
    )
    global_current_scene[] = scene
    scene
end



function merged_get!(defaults::Function, key, scene, input::Attributes)
    theme = get!(defaults, scene.theme, key)
    rest = Attributes()
    merged = Attributes()

    for key in union(keys(input), keys(theme))
        if haskey(input, key) && haskey(theme, key)
            merged[key] = to_node(input[key])
        elseif haskey(input, key)
            rest[key] = input[key]
        else # haskey(theme) must be true!
            merged[key] = theme[key]
        end
    end
    merged, rest
end

Theme(; kw_args...) = Attributes(map(kw-> kw[1] => to_node(kw[2]), kw_args))
