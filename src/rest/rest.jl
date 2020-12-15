export fetchval

const SHOULD_SEND = Dict(:PATCH => true, :POST => true, :PUT => true)

# Lists of events fired by sending a request to each endpoint.
const EVENTS_FIRED = Dict(
    :DELETE => [
        (r"^/channels/\d+$", ChannelDelete),
        (r"^/channels/\d+$", ChannelUpdate),
        (r"^/channels/\d+/messages/\d+/reactions/.+/@me$", MessageReactionRemove),
        (r"^/channels/\d+/messages/\d+/reactions/.+/\d+$", MessageReactionRemove),
        (r"^/channels/\d+/messages/\d+/reactions$", MessageReactionRemoveAll),
        (r"^/channels/\d+/messages/\d+$", MessageDelete),
        (r"^/channels/\d+/messages/bulk-delete$", MessageDeleteBulk),
        (r"^/channels/\d+/permissions/\d+$", ChannelUpdate),
        (r"^/channels/\d+/pins/\d+$", ChannelPinsUpdate),
        (r"^/channels/\d+/pins/\d+$", MessageUpdate),
        (r"^/channels/\d+/recipients/\d+$", ChannelUpdate),  # Untested.
        (r"^/guilds/\d+/emojis/\d+$", GuildEmojisUpdate),
        (r"^/guilds/\d+$", GuildDelete),
        (r"^/guilds/\d+/members/\d+/roles/\d+$", GuildMemberUpdate),
        (r"^/guilds/\d+/members/\d+/$", GuildMemberRemove),
        (r"^/guilds/\d+/bans/\d+$", GuildBanRemove),
        (r"^/guilds/\d+/roles/\d+$", GuildRoleDelete),
        (r"^/guilds/\d+/integrations$", GuildIntegrationsUpdate),
        (r"^/users/@me/guilds/\d+$", GuildMemberRemove),
        (r"^/users/@me/guilds/\d+$", PresenceUpdate),
        (r"^/webhooks/\d+$", WebhooksUpdate),
        (r"^/webhooks/\d+/.+$", WebhooksUpdate),
    ],
    :POST => [
        (r"^/channels/\d+/messages$", MessageCreate),
        (r"^/channels/\d+/typing$", TypingStart),
        (r"^/guilds/\d+/emojis$", GuildEmojisUpdate),
        (r"^/guilds$", GuildCreate),
        (r"^/guilds/\d+/channels$", ChannelCreate),
        (r"^/guilds/\d+/roles$", GuildRoleCreate),
        (r"^/guilds/\d+/prune$", GuildMemberRemove),
        (r"^/guilds/\d+/integrations$", GuildIntegrationsUpdate),
        (r"^/users/@me/channels$", ChannelCreate),
        (r"^/channels/\d+/webhooks$", WebhooksUpdate),
    ],
    :PUT => [
        (r"^/channels/\d+$", ChannelUpdate),
        (r"^/channels/\d+/messages/\d+/reactions/.+/@me$", MessageReactionAdd),
        (r"^/channels/\d+/permissions/\d+$", ChannelUpdate),
        (r"^/channels/\d+/pins/\d+$", ChannelPinsUpdate),
        (r"^/channels/\d+/pins/\d+$", MessageUpdate),
        (r"^/channels/\d+/recipients/\d+$", ChannelUpdate),  # Untested.
        (r"^/guilds/\d+/members/\d+$", GuildMemberAdd),
        (r"^/guilds/\d+/members/\d+/roles/\d+$", GuildMemberUpdate),
        (r"^/guilds/\d+/bans/\d+$", GuildBanAdd),
    ],
    :PATCH => [
        (r"^/channels/\d+$", ChannelUpdate),
        (r"^/channels/\d+/messages/\d+$", MessageUpdate),
        (r"^/guilds/\d+/emojis/\d+$", GuildEmojisUpdate),
        (r"^/guilds/\d+$", GuildUpdate),
        (r"^/guilds/\d+/channels$", ChannelUpdate),
        (r"^/guilds/\d+/members/\d+$", GuildMemberUpdate),
        (r"^/guilds/\d+/members/@me/nick$", GuildMemberUpdate),
        (r"^/guilds/\d+/roles$", GuildRoleUpdate),
        (r"^/guilds/\d+/roles/\d+$", GuildRoleUpdate),
        (r"^/guilds/\d+/integrations$", GuildIntegrationsUpdate),
        (r"^/users/@me$", UserUpdate),
        (r"^/webhooks/\d+$", WebhooksUpdate),
        (r"^/webhooks/\d+/.+$", WebhooksUpdate),
    ],
)

"""
A wrapper around a response from the REST API. Every function which wraps a Discord REST
API endpoint returns a `Future` which will contain a value of this type. To retrieve the
`Response` from the `Future`, use `fetch`. See also: [`fetchval`](@ref).

## Fields
- `val::Nullable{T}`: The object contained in the HTTP response. For example, for a
  call to [`get_channel_message`](@ref), this value will be a [`Message`](@ref).
- `ok::Bool`: The state of the request. If `true`, then it is safe to access `val`.
- `http_response::Nullable{HTTP.Messages.Response}`: The underlying HTTP response, if
  a request was made.
- `exception::Nullable{Exception}`: The caught exception, if one is thrown.

## Examples
Multiple API calls which immediately return `Future`s and can be awaited:
```julia
futures = map(i -> create_message(c, channel_id; content=string(i)), 1:10);
other_work_here()
resps = fetch.(futures)
```
Skipping error checks and returning the value directly:
```julia
guild = fetchval(create_guild(c; name="foo"))
```
"""
struct Response{T}
    val::Nullable{T}
    ok::Bool
    http_response::Nullable{HTTP.Messages.Response}
    exception::Nullable{Exception}
end

# HTTP response with no body.
function Response{Nothing}(r::HTTP.Messages.Response)
    return Response{Nothing}(nothing, r.status < 300, r, nothing)
end

# HTTP response with body (maybe).
function Response{T}(c::Client, r::HTTP.Messages.Response) where T
    r.status == 204 && return Response{T}(nothing, true, r, nothing)
    r.status >= 300 && return Response{T}(nothing, false, r, nothing)

    data = if HTTP.header(r, "Content-Type") == "application/json"
        JSON.parse(String(copy(r.body)); dicttype=Dict{Symbol, Any})
    else
        copy(r.body)
    end

    val, e = tryparse(c, T, data)
    return Response{T}(val, e === nothing, r, e)
end

# HTTP request with no expected response body.
function Response(
    c::Client,
    method::Symbol,
    endpoint::AbstractString;
    body="",
    kwargs...
)
    return Response{Nothing}(c, method, endpoint; body=body, kwargs...)
end

# HTTP request.
function Response{T}(
    c::Client,
    method::Symbol,
    endpoint::AbstractString,
    cachetest::Function=alwaystrue;
    headers=Dict(),
    body=HTTP.nobody,
    kwargs...
) where T
    f = Future()

    @async begin
        kws = (
            channel=cap("channels", endpoint),
            guild=cap("guilds", endpoint),
            message=cap("messages", endpoint),
            user=cap("users", endpoint),
        )

        # Retrieve the value from the cache, maybe.
        if c.use_cache && method === :GET
            val = get(c.state, T; kws...)
            if val !== nothing
                try
                    # Only use the value if it satisfies the cache test.
                    if cachetest(val) === true
                        put!(f, Response{T}(val, true, nothing, nothing))
                        return
                    end
                catch
                    # TODO: Log this?
                end
            end
        end

        # Prepare the request.
        url = "$DISCORD_API/v$(c.version)$endpoint"
        isempty(kwargs) || (url *= "?" * HTTP.escapeuri(kwargs))
        headers = merge(Dict(
            "User-Agent" => c.user_agent,
            "Content-Type" => "application/json",
            "Authorization" => c.token,
        ), Dict(headers))
        args = [method, url, headers]
        if get(SHOULD_SEND, method, false)
            push!(args, headers["Content-Type"] == "application/json" ? json(body) : body)
        end

        # Queue a job to be run within the rate-limiting constraints.
        enqueue!(c.limiter, method, endpoint) do
            http_r = nothing

            try
                # Make an HTTP request, and generate a Response.
                # If we hit an upstream rate limit, return the response immediately.
                http_r = HTTP.request(args...; status_exception=false)
                http_r.status == 429 && return http_r
                r = Response{T}(c, http_r)

                if r.ok && r.val !== nothing && should_put(c, method, endpoint)
                    # Cache the value, and also replace any missing data
                    # in the response with data from the cache.
                    r = @set r.val = put!(c.state, r.val; kws...)
                end

                # Store the successful Response to the Future.
                put!(f, r)
            catch e
                kws = logkws(c; conn=undef, exception=(e, catch_backtrace()))
                @error "Creating response failed" kws...
                put!(f, Response{T}(nothing, false, http_r, e))
            end

            return http_r  # Return the HTTP response to update the rate limits.
        end
    end

    return f
end

Base.eltype(::Response{T}) where T = T
Base.eltype(::Type{Response{T}}) where T = T

"""
    fetchval(f::Future{Response{T}}) -> Nullable{T}

Shortcut for `fetch(f).val`: Fetch a [`Response`](@ref) and return its value. Note that
there are no guarantees about the response's success and the value being returned, and it
discards context that can be useful for debugging, such as HTTP responses and caught
exceptions.
"""
fetchval(f::Future) = fetch(f).val

# Capture an ID from a string.
function cap(path::AbstractString, s::AbstractString)
    m = match(Regex("/$path/(\\d+)"), s)
    return m === nothing ? nothing : parse(Snowflake, first(m.captures))
end

# Determine whether we should cache something for the request.
function should_put(c::Client, method::Symbol, endpoint::AbstractString)
    # TODO: Maybe we could use the type of the Response value to be more granular.
    # e.g. if we got a Message, then only check handlers for types with a Message field.
    c.use_cache || return false
    isopen(c) || return true
    method === :GET && return true

    Ts = map(
        last,
        Iterators.filter(t -> match(t[1], endpoint) !== nothing, EVENTS_FIRED[method]),
    )
    return !all(T -> hasdefault(c, T), Ts)
end

include(joinpath("endpoints", "endpoints.jl"))
include(joinpath("crud", "crud.jl"))
