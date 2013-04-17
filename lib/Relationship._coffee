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
    # @param value {Object} The property value to index under, e.g. `1346713658393`.
    # @param callback {Function}
    #
    index: (index, key, value, _) ->
        try
            # TODO
            if not @exists
                throw new Error 'Relationship must exists before indexing properties'

            services = @db.getServices _
            version = @db.getVersion _

            # old API:
            if version <= 1.4
                encodedKey = encodeURIComponent key
                encodedValue = encodeURIComponent value
                url = "#{services.relationship_index}/#{index}/#{encodedKey}/#{encodedValue}"

                response = @_request.post
                    url: url
                    json: @self
                , _

            # new API:
            else
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
