status = require 'http-status'

util = require './util'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer'

module.exports = class Relationship extends PropertyContainer
    constructor: (db, data, start, end) ->
        super db, data

        # require Node inline to prevent circular require dependency:
        Node = require './Node'

        # TODO relationship "start" and "end" are inconsistent with
        # creating relationships "to" and "from". consider renaming.
        @_start = start or new Node db, {self: data.start}
        @_end = end or new Node db, {self: data.end}

    # Language helpers:
    get = (props) =>
        @::__defineGetter__ name, getter for name, getter of props
    set = (props) =>
        @::__defineSetter__ name, setter for name, setter of props

    # Properties:
    get start: -> @_start or null
    get end: -> @_end or null
    get type: -> @_data.type

    # Methods:
    save: (_) ->
        try
            # TODO: check for actual modification
            if @exists
                response = @_request.put
                    uri: "#{@self}/properties"
                    json: @data
                , _

                if response.statusCode isnt status.NO_CONTENT
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.BAD_REQUEST
                            message = 'Invalid data sent'
                        when status.NOT_FOUND
                            message = 'Relationship not found'
                    throw new Error message

                # explicitly returning nothing to make this a "void" method.
                return

        catch error
            throw adjustError error

    # Alias
    del: @::delete
    
    # Index
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
