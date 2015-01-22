status = require 'http-status'

util = require './util'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer'
Relationship = require './Relationship'
Path = require './Path'

#
# The class corresponding to a Neo4j node.
#
module.exports = class Node extends PropertyContainer

    #
    # Construct a new wrapper around a Neo4j node with the given data directly
    # from the server at the given Neo4j {GraphDatabase}.
    #
    # @private
    # @param db {GraphDatbase}
    # @param data {Object}
    #
    constructor: (db, data) ->
        super db, data

    #
    # Return a human-readable string representation of this node,
    # suitable for development purposes (e.g. debugging).
    #
    # @return {String}
    #
    toString: ->
        if @exists then "node @#{@id}"
        else "unsaved node (#{JSON.stringify @data, null, 4})"

    #
    # Persist or update this node in the database. "Returns" (via callback)
    # this same instance after the save.
    #
    # @param callback {Function}
    # @return {Node}
    #
    save: (_) ->
        try
            # TODO: check for actual modification
            if @exists
                response = @_request.put
                    uri: "#{@self}/properties"
                    json: @data
                , _

                if response.statusCode isnt status.NO_CONTENT
                    switch response.statusCode
                        when status.BAD_REQUEST
                            throw new Error 'Invalid data sent'
                        when status.NOT_FOUND
                            throw new Error 'Node not found'
                        else
                            throw response

            else
                services = @db.getServices _

                response = @_request.post
                    uri: services.node
                    json: @data
                , _

                if response.statusCode isnt status.CREATED
                    switch response.statusCode
                        when status.BAD_REQUEST
                            throw new Error 'Invalid data sent'
                        else
                            throw response

                # only update our copy of the data when it is POSTed.
                @_data = response.body

            # either way, "return" (callback) this created or updated node:
            return @

        catch error
            throw adjustError error

    #
    # Delete this node from the database. This will throw an error if this
    # node has any relationships on it, unless the `force` flag is passed in,
    # in which case those relationships are also deleted.
    #
    # @note For safety, it's recommended to *not* pass the `force` flag and
    #   instead manually and explicitly delete known relationships beforehand.
    #
    # @param callback {Function}
    # @param force {Boolean} If this node has any relationships on it, whether
    #   those relationships should be deleted as well.
    #
    delete: (_, force=false) ->
        if not @exists
            return

        try
            # Should we force-delete all relationships on this node?
            # If so, fetch and delete in parallel:
            if force
                relationships = @all null, _
                relationships.forEach_ _, {parallel: true}, (_, rel) ->
                    rel.delete _

        catch error
            throw adjustError error

        # *Then* delete the node
        super

    #
    # Add this node to the given index under the given key-value pair.
    #
    # @param index {String} The name of the index, e.g. `'users'`.
    # @param key {String} The key to index under, e.g. `'username'`.
    # @param value {String} The value to index under, e.g. `'aseemk'`.
    # @param callback {Function}
    #
    index: (index, key, value, _) ->
        try
            if not @exists
                throw new Error 'Node must exist before indexing.'

            services = @db.getServices _

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

    #
    # Delete this node from the given index, optionally under the given key
    # or key-value pair. (A key is required if a value is given.)
    #
    # @param index {String} The name of the index, e.g. `'users'`.
    # @param key {String} (Optional) The key to unindex from, e.g. `'username'`.
    # @param value {String} (Optional) The value to unindex from, e.g. `'aseemk'`.
    # @param callback {Function}
    #
    unindex: (index, key, value, _) ->
        # see below for the code that normalizes the args;
        # this function assumes all args are present (but may be null/etc.).
        try
            if not @exists
                throw new Error 'Node must exist before unindexing.'

            services = @db.getServices _

            key = encodeURIComponent key if key
            value = encodeURIComponent value if value
            base = "#{services.node_index}/#{encodeURIComponent index}"
            url =
                if key and value
                    "#{base}/#{key}/#{value}/#{@id}"
                else if key
                    "#{base}/#{key}/#{@id}"
                else
                    "#{base}/#{@id}"

            response = @_request.del url, _

            if response.statusCode isnt status.NO_CONTENT
                # database error
                throw response

            # success
            return

        catch error
            throw adjustError error

    # helper for overloaded unindex() method:
    do (actual = @::unindex) =>
        @::unindex = (index, key, value, callback) ->
            if typeof key is 'function'
                callback = key
                key = null
                value = null
            else if typeof value is 'function'
                callback = value
                value = null

            actual.call @, index, key, value, callback

    #
    # Create and "return" (via callback) a relationship of the given type, and
    # optionally with the given properties, from this node to another node.
    #
    # @param otherNode {Node}
    # @param type {String}
    # @param data {Object} (Optional) The properties this relationship should have.
    # @param callback {Function}
    # @return {Relationship}
    #
    createRelationshipTo: (otherNode, type, data, cb) ->
        # support omitting data:
        if typeof data is 'function'
            cb = data
            data = null

        @_createRelationship this, otherNode, type, data, cb

    #
    # Create and "return" (via callback) a relationship of the given type, and
    # optionally with the given properties, from another node to this node.
    #
    # @param otherNode {Node}
    # @param type {String}
    # @param data {Object} (Optional) The properties this relationship should have.
    # @param callback {Function}
    # @return {Relationship}
    #
    createRelationshipFrom: (otherNode, type, data, cb) ->
        # support omitting data:
        if typeof data is 'function'
            cb = data
            data = null

        @_createRelationship otherNode, this, type, data, cb

    #
    # Create and "return" (via callback) a relationship of the given type and
    # with the given properties between one node and another node.
    #
    # @private
    # @param from {Node}
    # @param to {Node}
    # @param type {String}
    # @param data {Object} The properties this relationship should have.
    # @param callback {Function}
    # @return {Relationship}
    #
    _createRelationship: (from, to, type, data={}, _) ->
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

                # client or database error:
                if response.statusCode isnt status.CREATED
                    {message, exception} = response.body or {}
                    message or= exception or switch response.statusCode
                        when status.BAD_REQUEST
                            "Invalid createRelationship: #{from.id} #{type} #{to.id} w/ data: #{JSON.stringify data}"
                        when status.CONFLICT
                            '"to" node, or the node specified by the URI not found'
                        else
                            throw response  # e.g. internal server error
                    throw new Error message

                # success
                return new Relationship @db, response.body, from, to
            else
                throw new Error 'Failed to create relationship'

        catch error
            throw adjustError error

    ##
    # TODO Document
    #
    # @todo Support passing in no type, e.g. for all types?
    # @todo To be consistent with the REST and Java APIs, this returns an
    #   array of all returned relationships. It would certainly be more
    #   user-friendly though if it returned a dictionary of relationships
    #   mapped by type.
    # @todo This takes direction and type as separate parameters, while the
    #   {#getRelationshipNodes getRelationshipNodes()} method combines both
    #   as an object. Should we change one or the other? Unfortunately, the
    #   REST API is also inconsistent like this...
    #
    # @private
    # @param direction {String} 'incoming', 'outgoing', or 'all'
    # @param type {String, Array<String>}
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
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

    #
    # Fetch and "return" (via callback) the relationships of the given type or
    # types from or to this node.
    #
    # @param type {String, Array<String>}
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
    getRelationships: (type, _) ->
        @all type, _

    #
    # Fetch and "return" (via callback) the relationships of the given type or
    # types from this node.
    #
    # @param type {String, Array<String>}
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
    outgoing: (type, _) ->
        @_getRelationships 'outgoing', type, _

    #
    # Fetch and "return" (via callback) the relationships of the given type or
    # types to this node.
    #
    # @param type {String, Array<String>}
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
    incoming: (type, _) ->
        @_getRelationships 'incoming', type, _

    #
    # Fetch and "return" (via callback) the relationships of the given type or
    # types from or to this node.
    #
    # @todo This aliases {#getRelationships}, but is that redundant?
    #
    # @param type {String, Array<String>}
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
    all: (type, _) ->
        @_getRelationships 'all', type, _

    #
    # Fetch and "return" (via callback) the nodes adjacent to this one
    # following only relationships of the given type(s) and/or direction(s).
    #
    # @todo This could/should probably be renamed e.g. `getAdjacentNodes()`.
    #
    # @param rels {String, Array<String>, Object, Array<Object>}
    #   This can be a string type, e.g. `'likes'`, in which case both
    #   directions are traversed.
    #   Or it can be an array of string types, e.g. `['likes', 'loves']`.
    #   It can also be an object, e.g. `{type: 'likes', direction: 'out'}`.
    #   Finally, it can be an array of objects, e.g.
    #   `[{type: 'likes', direction: 'out'}, ...]`.
    # @param callback {Function}
    # @return {Array<Node>}
    #
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

    #
    # Fetch and "return" (via callback) the shortest path, if there is one,
    # from this node to the given node. Returns null if no path exists.
    #
    # @todo Support other algorithms, which may require extra parameters, by
    #   changing this method to take an options object.
    # @todo Support multiple relationship types/directions?
    #
    # @param to {Node}
    # @param type {String} The type of relationship to follow.
    # @param direction {String} One of `'in'`, `'out'`, or `'all'`.
    # @param maxDepth {Number} The maximum number of relationships to follow
    #   when searching for paths. The default is 1.
    # @param algorithm {String} This needs to be `'shortestPath'` for now.
    # @param callback {Function}
    # @return {Path}
    #
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
