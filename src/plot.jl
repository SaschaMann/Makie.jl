convert_arguments(P, y::RealVector) = convert_arguments(0:length(y), y)
convert_arguments(P, x::RealVector, y::RealVector) = (Point2f0.(x, y),)
convert_arguments(P, x::RealVector, y::RealVector, z::RealVector) = (Point3f0.(x, y, z),)
convert_arguments(::Type{Text}, x::AbstractString) = (String(x),)
convert_arguments(P, x::AbstractVector{<: VecTypes}) = (x,)
convert_arguments(P, x::GeometryPrimitive) = (decompose(Point, x),)

function convert_arguments(P, x::AbstractVector, y::AbstractVector, z::AbstractMatrix)
    (x, y, z)
end
function convert_arguments(P, x::ClosedInterval, y::ClosedInterval, z::AbstractMatrix)
    (x, y, z)
end
function convert_arguments(P, data::AbstractMatrix)
    n, m = Float64.(size(data))
    (0.0 .. n, 0.0 .. m, data)
end
function convert_arguments(P, x::AbstractVector{T1}, y::AbstractVector{T2}, f::Function) where {T1, T2}
    if !applicable(f, x[1], y[1])
        error("You need to pass a function with signature f(x::$T1, y::$T2). Found: $f")
    end
    T = typeof(f(x[1], y[1]))
    z = similar(x, T, (length(x), length(y)))
    z .= f.(x, y')
    (x, y, z)
end

function convert_arguments(P, x::Rect)
    # TODO fix the order of decompose
    (decompose(Point, x)[[1, 2, 4, 3, 1]],)
end


plot(args...; kw_args...) = plot!(Scene(), Scatter, args...; kw_args...)
plot(scene::Scene, args...; kw_args...) = plot!(scene, Scatter, args...; kw_args...)
plot(scene::Scene, P::Type, args...; kw_args...) = plot!(scene, P, args...; kw_args...)
plot(P::Type, args...; kw_args...) = plot!(Scene(), P, args...; kw_args...)

plot!(args...; kw_args...) = plot!(current_scene(), Scatter, args...; kw_args...)
plot!(scene::Scene, args...; kw_args...) = plot!(scene, Scatter, args...; kw_args...)
plot!(P::Type, args...; kw_args...) = plot!(current_scene(), P, Attributes(kw_args), args...)
plot!(P::Type, attributes::Attributes, args...) = plot!(current_scene(), P, attributes, args...)
plot!(scene::Scene, P::Type, args...; kw_args...) = plot!(scene, P, Attributes(kw_args), args...)

function plot!(scene::Scene, P::Type, attributes::Attributes, args...)
    plot!(scene, P, attributes, convert_arguments(P, args...)...)
end

function plot!(scene::Scene, p::AbstractPlot, attributes::Attributes)
    plot_attributes, rest = merged_get!(:plot, scene, attributes) do
        Theme(
            show_axis = false,
            show_legend = false,
            scale_plot = false,
            center = false,
            axis = Attributes(),
            legend = Attributes(),
            scale = Vec3f0(1),
            camera = :automatic,
            limits = :automatic,
            padding = (0.1, 0.1)
        )
    end
    if !isempty(rest) # at this point, there should be no attributes left.
        warn("The following attributes are unused: $(sprint(show, rest))")
    end
    limits = map(plot_attributes[:limits], data_limits(p)) do limit, dlimits
        if limit == :automatic
            dlimits
        else
            limit
        end
    end
    scale = if plot_attributes[:scale_plot][]
        map_once(scene.px_area, limits) do rect, limits
            l = ((limits[1][1], limits[2][1]), (limits[1][2], limits[2][2]))
            xyzfit = fit_ratio(rect, l)
            s = to_ndim(Vec3f0, xyzfit, 1f0)
            p[:transformation][][:scale][] = s
            s
        end
    else
        Vec3f0(1)
    end

    if plot_attributes[:show_axis][]
        axis_attributes = plot_attributes[:axis][]
        axis_attributes[:scale] = scale
        axis2d(scene, axis_attributes, limits)
    end

    if plot_attributes[:show_legend][]
        legend_attributes = plot_attributes[:legend][]
        legend_attributes[:scale] = scale
        legend(scene, limits, legend_attributes)
    end
    if plot_attributes[:camera][] == :automatic
        # if length(limits[][1]) == 2
        #     cam2d!(scene)
        # elseif length(limits[][1]) == 3
        #     cam3d!(scene)
        # else
        #     @assert false "Scene limits should be 2d or 3d. Found limits: $limits"
        # end
    end
    push!(scene, p)
    p#Series(Scene, p, plot_attributes)
end