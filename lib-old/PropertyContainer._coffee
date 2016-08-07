status = require 'http-status'

util = require './util'
adjustError = util.adjustError

#
# The abstract class corresponding to a Neo4j property container.
#
# @abstract
#
module.exports = class PropertyContainer

    #
    # Construct a new wrapper around a Neo4j property container with the given
    # data directly from the server at the given Neo4j {GraphDatabase}.
    #
    # @private
    # @param db {GraphDatbase}
    # @param data {Object}
    #
    constructor: (db, data) ->
        @db = db
        @_request = db._request     # convenience alias

        @_data = data or {}
        @_data.self = data?.self or null

    ### Language helpers: ###

    get = (props) =>
        @::__defineGetter__ name, getter for name, getter of props
    set = (props) =>
        @::__defineSetter__ name, setter for name, setter of props

    ### Properties: ###

    #
    # @property {String} The URL of this property container.
    #
    # @todo This might be an implementation detail; should we remove it?
    #   If not, should it at least be renamed to just URL?
    #
    get self: -> @_data.self or null

    #
    # @property {Boolean} Whether this property container exists in
    #   (has been persisted to) the Neo4j database.
    #
    get exists: -> @self?

    #
    # @property {Number} If this property container exists, its Neo4j
    #   integer ID.
    #
    get id: ->
        if not @exists
            null
        else
            match = /(?:node|relationship)\/(\d+)$/.exec @self
            parseInt match[1]

    #
    # @property {Object} This property container's properties. This is a map
    #   of key-value pairs.
    #
    get data: -> @_data.data or null
    set data: (value) -> @_data.data = value

    ### Methods: ###

    #
    # Test whether the given object represents the same property container as
    # this one. They can be separate instances with separate data.
    #
    # @param other {Object}
    # @return {Boolean}
    #
    equals: (other) ->
        @self is other?.self

    #
    # Delete this property container from the database.
    #
    # @param callback {Function}
    #
    delete: (_) ->
        if not @exists
            return

        try
            response = @_request.del @self, _

            if response.statusCode isnt status.NO_CONTENT
                switch response.statusCode
                    when status.NOT_FOUND
                        throw new Error 'PropertyContainer not found'
                    when status.CONFLICT
                        throw new Error 'Node could not be deleted (still has relationships?)'
                    else
                        throw response

            # success
            @_data.self = null

            return

        catch error
            throw adjustError error

    #
    # A convenience alias for {#delete} since `delete` is a reserved keyword
    # in JavaScript.
    #
    # @see #delete
    #
    del: ->
        @delete.apply @, arguments

    #
    # Return a JSON representation of this property container, suitable for
    # serialization (e.g. caching).
    #
    # @return {Object}
    #
    toJSON: ->
        # take the basic info for this db, then just add the data object
        # directly since we need that for deserialization/construction.
        # TODO it'd be great if we could store a trimmed down version of
        # the data object instead of e.g. all the hypermedia URLs...
        # but we need those hypermedia URLs for making requests for now.
        json = @db._toJSON @
        json._data = @_data
        json

    #
    # Returns an instance of this property container for the given object,
    # parsed from JSON.
    #
    # @private
    # @param db {GraphDatabase}
    # @param obj {Object}
    #
    @_fromJSON: (db, obj) ->
        {_data} = obj
        new @ db, _data
