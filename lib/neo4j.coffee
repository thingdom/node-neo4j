class GraphDatabase
    constructor: (url) ->
        @url = url

    createNode: (data) ->
        node = new Node this, data


class PropertyContainer
    constructor: (db, data) ->
        @db = db
        @data = data

        @_self = null

        @getter 'self', -> @_self || null
        @getter 'exists', -> @_self?

    getter: @__defineGetter__
    setter: @__defineSetter__


class Node extends PropertyContainer
    constructor: (db, data) ->
        super db, data

    save: ->
    destroy: ->


class Relationship extends PropertyContainer
    constructor: (db, start, end, type, data) ->
        super db, data

        @_start = start
        @_end = end
        @_type = type || null
        
        @getter 'type', -> @_type

    save: ->
    destroy: ->


# Exports
exports.GraphDatabase = GraphDatabase
