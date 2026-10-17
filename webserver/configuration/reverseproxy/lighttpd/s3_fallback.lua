if lighty.status == 404 then
    -- Get the rewritten URI (without the asset prefix)
    local orig_uri = lighty.env["request.uri"]
    
    -- Internal redirect to our fallback block carrying over the path
    lighty.env["request.uri"] = "/fallback_XXXXASSETSXXXX" .. orig_uri
    return lighty.RESTART_REQUEST
end
