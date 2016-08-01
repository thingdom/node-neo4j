
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

        if property_keys.length > 1
            console.warn "Index (on :#{label}) with #{property_keys.length}
                property keys encountered: #{property_keys.join ', '}.
                node-neo4j v#{lib.version} doesn’t know how to handle these.
                Continuing with only the first one."

        [property] = property_keys

        return new Index {label, property}
