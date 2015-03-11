
module.exports = class Index

    constructor: (opts={}) ->
        {@label, @property} = opts

    equals: (other) ->
        (other instanceof Index) and (@label is other.label) and
            (@property is other.property)

    toString: ->
        "INDEX ON :#{@label}(#{@property})"  # E.g. "INDEX ON :User(email)"

    #
    # Accepts the given raw JSON from Neo4j's REST API representing an index,
    # and creates and returns a Index instance from it.
    #
    @_fromRaw: (obj) ->
        {label, property_keys} = obj

        # TODO: Neo4j always returns an array of property keys, but only one
        # property key is supported today. Do we need to support multiple?
        [property] = property_keys

        return new Index {label, property}
