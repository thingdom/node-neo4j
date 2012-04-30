status = require 'http-status'

util = require './util'
adjustError = util.adjustError

module.exports = class PropertyContainer
    constructor: (db, data) ->
        @db = db
        @_request = db._request     # convenience alias

        @_data = data or {}
        @_data.self = data?.self or null

    # Language helpers:
    get = (props) =>
        @::__defineGetter__ name, getter for name, getter of props
    set = (props) =>
        @::__defineSetter__ name, setter for name, setter of props

    # Properties:
    get self: -> @_data.self or null
    get exists: -> @self?
    get id: ->
        if not @exists
            null
        else
            match = /(?:node|relationship)\/(\d+)$/.exec @self
            parseInt match[1]

    get data: -> @_data.data or null
    set data: (value) -> @_data.data = value

    # Methods:
    equals: (other) ->
        @self is other?.self

    delete: (_) ->
        if not @exists
            return

        try
            response = @_request.del @self, _

            if response.statusCode isnt status.NO_CONTENT
                # database error
                message = ''
                switch response.statusCode
                    when status.NOT_FOUND
                        message = 'PropertyContainer not found'
                    when status.CONFLICT
                        message = 'Node could not be deleted (still has relationships?)'
                throw new Error message

            # success
            @_data.self = null

            return

        catch error
            throw adjustError error
