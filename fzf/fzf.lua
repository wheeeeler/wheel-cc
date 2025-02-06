function scuffedfzf(query, item)
    local tokens = {}
    for token in query:gmatch("%S+") do
        table.insert(tokens, token)
    end

    for _, token in ipairs(tokens) do
        local inverse, prefix, suffix, exact = false, false, false, false
        if token:sub(1, 1) == "!" then
            inverse = true
            token = token:sub(2)
        end
        if token:sub(1, 1) == "^" then
            prefix = true
            token = token:sub(2)
        end
        if token:sub(-1, -1) == "$" then
            suffix = true
            token = token:sub(1, -2)
        end
        if token:sub(1, 1) == "'" then
            exact = true
            token = token:sub(2)
        end

        local match = false
        if exact then
            match = item:find(token, 1, true) ~= nil
        elseif prefix then
            match = item:sub(1, #token) == token
        elseif suffix then
            match = item:sub(-#token) == token
        else
            match = item:find(token) ~= nil
        end

        if match and inverse or not match and not inverse then
            return false
        end
    end

    return true
end

return scuffedfzf
