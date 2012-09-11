flows = require 'streamline/lib/util/flows'
status = require 'http-status'

util = require './util'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer'
Relationship = require './Relationship'
Path = require './Path'

module.exports = class Node extends PropertyContainer
    constructor: (db, data) ->
        super db, data

    toString: ->
        if @exists then "node @#{@id}"
        else "unsaved node (#{JSON.stringify @data, null, 4})"

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
                    message = response.body?.message
                    switch response.statusCode
                        when status.BAD_REQUEST then message or= 'Invalid data sent'
                        when status.NOT_FOUND then message or= 'Node not found'
                    throw new Error message
            else
                services = @db.getServices _

                response = @_request.post
                    uri: services.node
                    json: @data
                , _

                if response.statusCode isnt status.CREATED
                    # database error
                    message = response.body?.message or 'Invalid data sent'
                    throw new Error message

                # only update our copy of the data when it is POSTed.
                @_data = response.body

            # either way, "return" (callback) this created or updated node:
            return @

        catch error
            throw adjustError error

    # throws an error if this node has any relationships on it, unless force
    # is true, in which case the relationships are also deleted.
    delete: (_, force=false) ->
        if not @exists
            return

        try
            # Should we force-delete all relationships on this node?
            # If so, fetch and delete in parallel:
            if force
                relationships = @all null, _
                flows.collect _,
                    for relationship in relationships
                        relationship.delete()

        catch error
            throw adjustError error

        # *Then* delete the node
        super

    # Alias
    del: @::delete

    createRelationshipTo: (otherNode, type, data, _) ->
        @_createRelationship this, otherNode, type, data, _

    createRelationshipFrom: (otherNode, type, data, _) ->
        @_createRelationship otherNode, this, type, data, _

    _createRelationship: (from, to, type, data, _) ->
        try
            # ensure this node exists
            # ensure otherNode exists
            # create relationship

            # XXX Can we really always assume `from` is loaded?
            createRelationshipURL = from._data['create_relationship']
            otherNodeURL = to.self

            if createRelationshipURL? and otherNodeURL
                response = @_request.post
                    url: createRelationshipURL
                    json:
                        to: otherNodeURL
                        data: data
                        type: type
                , _

                if response.statusCode isnt status.CREATED
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.BAD_REQUEST
                            message = response.body?.message or
                                      response.body?.exception or
                                      "Invalid createRelationship: #{from.id} #{type} #{to.id} w/ data: #{JSON.stringify data}"
                        when status.CONFLICT
                            message = '"to" node, or the node specified by the URI not found'
                    throw new Error message

                # success
                return new Relationship @db, response.body, from, to
            else
                throw new Error 'Failed to create relationship'

        catch error
            throw adjustError error

    # TODO support passing in no type, e.g. for all types?
    # TODO to be consistent with the REST and Java APIs, this returns an array
    # of all returned relationships. it would certainly be more user-friendly
    # though if it returned a dictionary of relationships mapped by type, no?
    # XXX TODO this takes direction and type as separate parameters, while the
    # getRelationshipNodes() method combines both as an object. inconsistent?
    # unfortunately, the REST API is also inconsistent like this...
    _getRelationships: (direction, type, _) ->
        # Method overload: No type specified
        # XXX can't support method overloading right now, because Streamline
        # doesn't allow "setting" the callback parameter like this requires.
        #if typeof type is 'function'
        #    _ = type
        #    type = []

        # Assume no types
        types = null

        # support passing in multiple types, as array
        if type?
            types = if type instanceof Array then type else [type]

        try
            if types?
                prefix = @_data["#{direction}_typed_relationships"]
                relationshipsURL = prefix?.replace '{-list|&|types}', types.join '&'
            else
                relationshipsURL = @_data["#{direction}_relationships"]

            if not relationshipsURL
                throw new Error 'Couldn\'t find URL of relationships endpoint.'

            resp = @_request.get relationshipsURL, _

            if resp.statusCode is status.NOT_FOUND
                throw new Error 'Node not found.'

            if resp.statusCode isnt status.OK
                throw new Error "Unrecognized response code: #{resp.statusCode}"

            # success
            return resp.body.map (data) =>
                # other node will automatically get filled in by Relationship
                if @self is data.start
                    new Relationship @db, data, this, null
                else
                    new Relationship @db, data, null, this

        catch error
            throw adjustError error

    # TODO to be consistent with the REST and Java APIs, this returns an array
    # of all returned relationships. it would certainly be more user-friendly
    # though if it returned a dictionary of relationships mapped by type, no?
    getRelationships: (type, _) ->
        @all type, _

    outgoing: (type, _) ->
        @_getRelationships 'outgoing', type, _

    incoming: (type, _) ->
        @_getRelationships 'incoming', type, _

    all: (type, _) ->
        @_getRelationships 'all', type, _

    path: (to, type, direction, maxDepth=1, algorithm='shortestPath', _) ->
        try
            pathURL = "#{@self}/path"
            data =
                to: to.self
                relationships:
                    type: type
                    direction: direction
                max_depth: maxDepth
                algorithm: algorithm

            res = @_request.post
                url: pathURL
                json: data
            , _

            if res.statusCode is status.NOT_FOUND
                # Empty path
                return null

            if res.statusCode isnt status.OK
                throw new Error "Unrecognized response code: #{res.statusCode}"

            # Parse result
            data = res.body

            # parsing manually (instead of using util.transform) in order to
            # preserve relationship type info (which we know but isn't in the
            # response):
            start = new Node this, {self: data.start}
            end = new Node this, {self: data.end}
            length = data.length
            nodes = data.nodes.map (url) =>
                new Node this, {self: url}
            relationships = data.relationships.map (url) =>
                new Relationship this, {self: url, type}

            # Return path
            return new Path start, end, length, nodes, relationships

        catch error
            throw adjustError error

    # XXX this is actually a traverse, but in lieu of defining a non-trivial
    # traverse() method, exposing this for now for our simple use case.
    # the rels parameter can be:
    # - just a string, e.g. 'has' (both directions traversed)
    # - an array of strings, e.g. 'has' and 'wants' (both directions traversed)
    # - just an object, e.g. {type: 'has', direction: 'out'}
    # - an array of objects, e.g. [{type: 'has', direction: 'out'}, ...]
    getRelationshipNodes: (rels, _) ->

        # support passing in both one rel and multiple rels, as array
        rels = if rels instanceof Array then rels else [rels]

        try
            traverseURL = @_data['traverse']?.replace '{returnType}', 'node'

            if not traverseURL
                throw new Error 'Traverse not available.'

            resp = @_request.post
                url: traverseURL
                json:
                    'max_depth': 1
                    'relationships': rels.map (rel) ->
                        if typeof rel is 'string' then {'type': rel} else rel
            , _

            if resp.statusCode is 404
                throw new Error resp.body?.message or 'Node not found.'

            if resp.statusCode isnt 200
                throw new Error resp.body?.message or "Unrecognized response code: #{resp.statusCode}"

            # success
            return resp.body.map (data) =>
                new Node @db, data

        catch error
            throw adjustError error

    index: (index, key, value, _) ->
        try
            # TODO
            if not @exists
                throw new Error 'Node must exists before indexing properties'

            services = @db.getServices _
            version = @db.getVersion _

            # old API:
            if version <= 1.4
                encodedKey = encodeURIComponent key
                encodedValue = encodeURIComponent value
                url = "#{services.node_index}/#{index}/#{encodedKey}/#{encodedValue}"

                response = @_request.post
                    url: url
                    json: @self
                , _

            # new API:
            else
                response = @_request.post
                    url: "#{services.node_index}/#{index}"
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
