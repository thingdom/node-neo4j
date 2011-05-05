status = require 'http-status'
request = require './request_'

util = require './util_'
adjustError = util.adjustError

GraphObject = require './GraphObject_'

module.exports = class Relationship extends GraphObject
    constructor: (db, start, end, type, data) ->
        super db, data

        # TODO relationship "start" and "end" are inconsistent with
        # creating relationships "to" and "from". consider renaming.
        @_start = start
        @_end = end
        @_type = type || null

        @getter 'start', -> @_start || null
        @getter 'end', -> @_end || null
        @getter 'type', -> @_type || null

    save: (_) ->
        try
            # TODO: check for actual modification
            if @exists
                response = request.put
                    uri: @self + '/properties'
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

                # success: update our copy of the data.
                # explicitly returning nothing to make this a "void" method.
                @_data = JSON.parse response.body
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

