status = require 'http-status'
request = require 'request'

util = require './util_'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer_'

module.exports = class Relationship extends PropertyContainer
    constructor: (db, start, end, type, data) ->
        super db, data

        # TODO relationship "start" and "end" are inconsistent with
        # creating relationships "to" and "from". consider renaming.
        @_start = start
        @_end = end
        @_type = type or null

        @getter 'start', -> @_start or null
        @getter 'end', -> @_end or null
        @getter 'type', -> @_type or null

    save: (_) ->
        try
            # TODO: check for actual modification
            if @exists
                response = request.put
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

    delete: (_) ->
        if not @exists
            return

        try
            response = request.del
                uri: @self
            , _

            if response.statusCode isnt status.NO_CONTENT
                # database error
                message = ''
                switch response.statusCode
                    when status.NOT_FOUND
                        message = 'Relationship not found'
                throw new Error message

            # success
            return

        catch error
            throw adjustError error

    # Alias
    del: @::delete

