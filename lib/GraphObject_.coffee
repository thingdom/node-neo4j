module.exports = class GraphObject
    constructor: (db, data) ->
        @db = db

        @_data = data || {}
        @_data.self = data?.self || null

        @getter 'self', -> @_data.self || null
        @getter 'exists', -> @self?
        @getter 'id', ->
            if not @exists
                null
            else
                match = /(?:node|relationship)\/(\d+)$/.exec @self
                #/ XXX slash to unbreak broken coda coffee plugin (which chokes on the regex with a slash)
                parseInt match[1]

        @getter 'data', -> @_data.data || null
        @setter 'data', (value) -> @_data.data = value

    getter: @::__defineGetter__
    setter: @::__defineSetter__

    equals: (other) ->
        @self is other?.self
