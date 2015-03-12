lib = require '../package.json'


module.exports = class Constraint

    constructor: (opts={}) ->
        {@label, @property} = opts

    equals: (other) ->
        (other instanceof Constraint) and (@label is other.label) and
            (@property is other.property)

    toString: ->
        # E.g. "CONSTRAINT ON (user:User) ASSERT user.email IS UNIQUE"
        node = @label.toLowerCase()
        "CONSTRAINT ON (#{node}:#{@label})
            ASSERT #{node}.#{@property} IS UNIQUE"

    #
    # Accepts the given raw JSON from Neo4j's REST API representing a
    # constraint, and creates and returns a Constraint instance from it.
    #
    @_fromRaw: (obj) ->
        {type, label, property_keys} = obj

        if type isnt 'UNIQUENESS'
            console.warn "Unrecognized constraint type encountered: #{type}.
                node-neo4j v#{lib.version} doesn’t know how to handle these.
                Continuing as if it’s a UNIQUENESS constraint..."

        # TODO: Neo4j always returns an array of property keys, but only one
        # property key is supported today. Do we need to support multiple?
        [property] = property_keys

        return new Constraint {label, property}
