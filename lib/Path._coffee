module.exports = class Path
    constructor: (start, end, length, nodes, relationships) ->
        @_start = start
        @_nodes = nodes
        @_length = length
        @_relationships = relationships
        @_end = end

    # Language helpers:
    get = (props) =>
        @::__defineGetter__ name, getter for name, getter of props
    set = (props) =>
        @::__defineSetter__ name, setter for name, setter of props

    # Properties:
    get start: -> @_start || null
    get end: -> @_end || null
    get length: -> @_length || 0
    get nodes: -> @_nodes || []
    get relationships: -> @_relationships || []
