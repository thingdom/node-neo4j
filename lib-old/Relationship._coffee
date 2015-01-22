status = require 'http-status'

util = require './util'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer'

#
# The class corresponding to a Neo4j relationship.
#
module.exports = class Relationship extends PropertyContainer

    #
    # Construct a new wrapper around a Neo4j relationship with the given data
    # directly from the server at the given Neo4j {GraphDatabase}.
    #
    # @private
    # @param db {GraphDatbase}
    # @param data {Object}
    # @param start {Node}
    # @param end {Node}
    #
    constructor: (db, data, start, end) ->
        super db, data

        # require Node inline to prevent circular require dependency:
        Node = require './Node'

        # TODO relationship "start" and "end" are inconsistent with
        # creating relationships "to" and "from". consider renaming.
        @_start = start or new Node db, {self: data.start}
        @_end = end or new Node db, {self: data.end}

    ### Language helpers: ###

    get = (props) =>
        @::__defineGetter__ name, getter for name, getter of props
    set = (props) =>
        @::__defineSetter__ name, setter for name, setter of props

    ### Properties: ###

    #
    # @property {Node} The node this relationship goes from.
    #
    get start: -> @_start or null

    #
    # @property {Node} The node this relationship goes to.
    #
    get end: -> @_end or null

    #
    # @property {String} This relationship's type.
    #
    get type: -> @_data.type

    ### Methods: ###

    #
    # Return a human-readable string representation of this relationship,
    # suitable for development purposes (e.g. debugging).
    #
    # @return {String}
    #
    toString: ->
        # this library has no notion of unsaved relationships,
        # so assume this relationship has an id:
        "relationship @#{@id} (#{@type})"

    #
    # Persist or update this relationship in the database. "Returns" (via
    # callback) this same instance after the save.
    #
    # @param callback {Function}
    # @return {Relationship}
    #
    save: (_) ->
        try
            # XXX assume this relationship already exists in the db; this
            # library doesn't provide unsaved Relationship instances.
            response = @_request.put
                uri: "#{@self}/properties"
                json: @data
            , _

            if response.statusCode isnt status.NO_CONTENT
                switch response.statusCode
                    when status.BAD_REQUEST
                        throw new Error 'Invalid data sent'
                    when status.NOT_FOUND
                        throw new Error 'Relationship not found'
                    else
                        throw response

            # either way, "return" (callback) this updated relationship:
            return @

        catch error
            throw adjustError error

    #
    # Add this relationship to the given relationship index under the given
    # property key and value.
    #
    # @param index {String} The name of the index, e.g. `'likes'`.
    # @param key {String} The property key to index under, e.g. `'created'`.
    # @param value {String} The property value to index under, e.g. `1346713658393`.
    # @param callback {Function}
    #
    index: (index, key, value, _) ->
        try
            if not @exists
                throw new Error 'Relationship must exist before indexing properties'

            services = @db.getServices _

            response = @_request.post
                url: "#{services.relationship_index}/#{index}"
                json:
                    key: key
                    value: value
                    uri: @self
            , _

            if response.statusCode isnt status.CREATED
                # database error
                throw response

            # success
            return

        catch error
            throw adjustError error

    #
    # Delete this relationship from the given index, optionally under the
    # given key or key-value pair. (A key is required if a value is given.)
    #
    # @param index {String} The name of the index, e.g. `'likes'`.
    # @param key {String} (Optional) The property key to unindex from, e.g. `'created'`.
    # @param value {String} (Optional) The property value to unindex from, e.g. `1346713658393`.
    # @param callback {Function}
    #
    unindex: (index, key, value, _) ->
        # see below for the code that normalizes the args;
        # this function assumes all args are present (but may be null/etc.).
        try
            if not @exists
                throw new Error 'Relationship must exist before unindexing.'

            services = @db.getServices _

            key = encodeURIComponent key if key
            value = encodeURIComponent value if value
            base = "#{services.relationship_index}/#{encodeURIComponent index}"
            url =
                if key and value
                    "#{base}/#{key}/#{value}/#{@id}"
                else if key
                    "#{base}/#{key}/#{@id}"
                else
                    "#{base}/#{@id}"

            response = @_request.del url, _

            if response.statusCode isnt status.NO_CONTENT
                # database error
                throw response

            # success
            return

        catch error
            throw adjustError error

    # helper for overloaded unindex() method:
    do (actual = @::unindex) =>
        @::unindex = (index, key, value, callback) ->
            if typeof key is 'function'
                callback = key
                key = null
                value = null
            else if typeof value is 'function'
                callback = value
                value = null

            actual.call @, index, key, value, callback
