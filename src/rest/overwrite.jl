export edit_overwrite,
    delete_overwrite

"""
    edit_overwrite(
        c::Client,
        overwrite::Union{Overwrite, Integer},
        channel::Union{DiscordChannel, Integer};
        params...,
    ) -> Response{Overwrite}

Modify an [`Overwrite`](@ref) in a [`DiscordChannel`](@ref).

# Keywords
- `allow::Integer`: the bitwise OR of the allowed permissions.
- `deny::Integer`: the bitwise OR of the denied permissions.
- `type::AbstractString`: "member" for a user or "role" for a role.

More details [here](https://discordapp.com/developers/docs/resources/channel#edit-channel-permissions).
"""
function edit_overwrite(c::Client, overwrite::Integer, channel::Integer; params...)
    return Response{Overwrite}(
        c,
        :PUT,
        "/channels/$channel/permissions/$overwrite";
        params...,
    )
end

function edit_overwrite(c::Client, o::Overwrite, channel::Integer; params...)
    return edit_overwrite(c, o.id, channel; params...)
end

function edit_overwrite(c::Client, overwrite::Integer, ch::DiscordChannel; params...)
    return edit_overwrite(c, overwrite, ch.id; params...)
end

function edit_overwrite(c::Client, o::Overwrite, ch::DiscordChannel; params...)
    return edit_overwrite(c, o.id, ch.id; params...)
end

"""
    delete_overwrite(
        c::Client,
        overwrite::Union{Overwrite, Integer},
        channel::Union{DiscordChannel, Integer}
    ) -> Response{Overwrite}

Delete an [`Overwrite`](@ref) in a [`DiscordChannel`](@ref).
"""
function delete_overwrite(c::Client, overwrite::Integer, channel::Integer)
    return Response{Overwrite}(c, :DELETE, "/channels/$channel/permissions/$overwrite")
end

function delete_overwrite(c::Client, o::Overwrite, ch::DiscordChannel)
    return delete_overwrite(c, o.id, ch.id)
end

function delete_overwrite(c::Client, o::Overwrite, channel::Integer)
    return delete_overwrite(c, o.id, channel)
end

function delete_overwrite(c::Client, overwrite::Integer, ch::DiscordChannel)
    return delete_overwrite(c, overwrite, ch.id)
end