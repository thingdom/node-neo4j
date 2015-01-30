utils = require './utils'

module.exports = class Relationship

    constructor: (opts={}) ->
        {@_id, @type, @properties, @_fromId, @_toId} = opts

    equals: (other) ->
        # TODO: Is this good enough? Often don't want exact equality, e.g.
        # nodes' properties may change between queries.
        (other instanceof Relationship) and (@_id is other._id)

    toString: ->
        "-[#{@_id}:#{@type}]-"  # E.g. -[123:FOLLOWS]-

    #
    # Accepts the given raw JSON from Neo4j's REST API, and if it represents a
    # valid relationship, creates and returns a Relationship instance from it.
    # If the JSON doesn't represent a valid relationship, returns null.
    #
    @_fromRaw: (obj) ->
        return null if (not obj) or (typeof obj isnt 'object')

        {data, self, type, start, end} = obj

        return null if (not self) or (typeof self isnt 'string') or
            (not type) or (typeof type isnt 'string') or
            (not start) or (typeof start isnt 'string') or
            (not end) or (typeof end isnt 'string') or
            (not data) or (typeof data isnt 'object')

        # Relationships also have `metadata`, added in Neo4j 2.1.5, but it
        # doesn't provide anything new. (And it doesn't give us from/to ID.)
        # We don't want to rely on it, so we don't bother using it at all.
        id = utils.parseId self
        fromId = utils.parseId start
        toId = utils.parseId end

        return new Relationship
            _id: id
            type: type
            properties: data
            _fromId: fromId
            _toId: toId
