module.exports = class PropertyContainer
    constructor: (db, data) ->
        @db = db

        @_data = data or {}
        @_data.self = data?.self or null

        @getter 'self', -> @_data.self or null
        @getter 'exists', -> @self?
        @getter 'id', ->
            if not @exists
                null
            else
                match = /(?:node|relationship)\/(\d+)$/.exec @self
                #/ XXX slash to unbreak broken coda coffee plugin (which chokes on the regex with a slash)
                parseInt match[1]

        @getter 'data', -> @_data.data or null
        @setter 'data', (value) -> @_data.data = value

    getter: @::__defineGetter__
    setter: @::__defineSetter__

    equals: (other) ->
        @self is other?.self
