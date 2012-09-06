#
# The class corresponding to a Neo4j path.
#
module.exports = class Path

    #
    # Construct a new wrapper around a Neo4j relationship with the given data
    # directly from the server at the given Neo4j {GraphDatabase}.
    #
    # @private
    # @param start {Node}
    # @param end {Node}
    # @param length {Number}
    # @param nodes {Array<Node>}
    # @param relationships {Array<Relationship>}
    #
    constructor: (start, end, length, nodes, relationships) ->
        @_start = start
        @_nodes = nodes
        @_length = length
        @_relationships = relationships
        @_end = end

    ### Language helpers: ###

    get = (props) =>
        @::__defineGetter__ name, getter for name, getter of props
    set = (props) =>
        @::__defineSetter__ name, setter for name, setter of props

    ### Properties: ###

    #
    # @property {Node} The node that this path starts at.
    #
    get start: -> @_start || null

    #
    # @property {Node} The node that this path ends at.
    #
    get end: -> @_end || null

    #
    # @property {Number} The length of this path.
    #
    get length: -> @_length || 0

    #
    # @property {Array<Node>} The nodes that make up this path.
    #
    get nodes: -> @_nodes || []

    #
    # @property {Array<Relationship>} The relationships that make up this path.
    #
    get relationships: -> @_relationships || []
