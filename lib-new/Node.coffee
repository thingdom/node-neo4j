utils = require './utils'

module.exports = class Node

    constructor: (opts={}) ->
        {@_id, @labels, @properties} = opts

    equals: (other) ->
        # TODO: Is this good enough? Often don't want exact equality, e.g.
        # nodes' properties may change between queries.
        (other instanceof Node) and (@_id is other._id)

    toString: ->
        labels = @labels.map (label) -> ":#{label}"
        "(#{@_id}#{labels.join ''})"    # E.g. (123), (456:Foo), (789:Foo:Bar)

    #
    # Accepts the given raw JSON from Neo4j's REST API, and if it represents a
    # valid node, creates and returns a Node instance from it.
    # If the JSON doesn't represent a valid node, returns null.
    #
    @_fromRaw: (obj) ->
        return null if (not obj) or (typeof obj isnt 'object')

        {data, metadata, self} = obj

        return null if (not self) or (typeof self isnt 'string') or
            (not data) or (typeof data isnt 'object')

        # Metadata was only added in Neo4j 2.1.5, so don't *require* it,
        # but (a) it makes our job easier, and (b) it's the only way we can get
        # labels, so warn the developer if it's missing, but only once.
        if metadata
            {id, labels} = metadata
        else
            id = utils.parseId self
            labels = null

            if not @_warnedMetadata
                @_warnedMetadata = true
                console.warn 'It looks like you’re running Neo4j <2.1.5.
                    Neo4j <2.1.5 didn’t return label metadata to drivers,
                    so node-neo4j has no way to associate nodes with labels.
                    Thus, the `labels` property on node-neo4j `Node` instances
                    will always be null for you. Consider upgrading to fix. =)
                    http://neo4j.com/release-notes/neo4j-2-1-5/'

        return new Node
            _id: id
            labels: labels
            properties: data
