status = require 'http-status'
request = require './request_'

util = require './util_'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer_'
Relationship = require './Relationship_'
Path = require './Path_'

module.exports = class Node extends PropertyContainer
    constructor: (db, data) ->
        super db, data

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
                        when status.BAD_REQUEST then message = 'Invalid data sent'
                        when status.NOT_FOUND then message = 'Node not found'
                    throw new Error message
            else
                services = @db.getServices _

                response = request.post
                    uri: services.node
                    json: @data
                , _

                if response.statusCode isnt status.CREATED
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.BAD_REQUEST then message = 'Invalid data sent'
                    throw new Error message

                # only update our copy of the data when it is POSTed
                @_data = JSON.parse response.body

            # explicitly not returning any value; making this a "void" method.
            return

        catch error
            throw adjustError error

    delete: (_) ->
        if not @exists
            return

        try

            # Delete all relationships, independent of type they have
            # TODO parallelize using Streamline
            # TODO only delete relationships if there’s a conflict?
            relationships = @all null, _
            for relationship in relationships
                relationship.delete _

            # Delete node
            response = request.del {uri: @self}, _

            if response.statusCode isnt status.NO_CONTENT
                # database error
                message = ''
                switch response.statusCode
                    when status.NOT_FOUND
                        message = 'Node not found'
                    when status.CONFLICT
                        message = 'Node could not be deleted (still has relationships?)'
                throw new Error message

            # success
            return

        catch error
            throw adjustError error

    # Alias
    del: @::delete

    # TODO why no createRelationshipFrom()? this actually isn't there in the
    # REST API, but we might be able to support it oursleves.
    createRelationshipTo: (otherNode, type, data, _) ->
        try
            # ensure this node exists
            # ensure otherNode exists
            # create relationship
            createRelationshipURL = @_data['create_relationship']
            otherNodeURL = otherNode.self
            if createRelationshipURL? and otherNodeURL
                response = request.post
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
                            message = 'Invalid data sent'
                        when status.CONFLICT
                            message = '"to" node, or the node specified by the URI not found'
                    throw new Error message

                # success
                data = JSON.parse response.body
                relationship = new Relationship @db, this, otherNode, type, data
                return relationship
            else
                throw new Error 'Failed to create relationship'

        catch error
            throw adjustError error

    # TODO support passing direction also? the REST API does, but having to
    # specify 'in', 'out' or 'all' here would be a bad string API. maybe add
    # getRelationshipsTo() and getRelationshipsFrom()?
    # TODO support passing in no type, e.g. for all types?
    # TODO to be consistent with the REST and Java APIs, this returns an array
    # of all returned relationships. it would certainly be more user-friendly
    # though if it returned a dictionary of relationships mapped by type, no?
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

            resp = request.get {url: relationshipsURL}, _

            if resp.statusCode is status.NOT_FOUND
                throw new Error 'Node not found.'

            if resp.statusCode isnt status.OK
                throw new Error "Unrecognized response code: #{resp.statusCode}"

            # success
            data = JSON.parse resp.body
            relationships = data.map (data) =>
                # XXX constructing a fake Node object for other node
                if @self is data.start
                    start = this
                    end = new Node @db, {self: data.end}
                else
                    start = new Node @db, {self: data.start}
                    end = this
                return new Relationship @db, start, end, type, data
            return relationships

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

            res = request.post
                url: pathURL
                json: data
            , _

            if res.statusCode is status.NOT_FOUND
                # Empty path
                return null

            if res.statusCode isnt status.OK
                throw new Error "Unrecognized response code: #{res.statusCode}"

            # Parse result
            data = JSON.parse res.body

            start = new Node this, {self: data.start}
            end = new Node this, {self: data.end}
            length = data.length
            nodes = data.nodes.map (url) =>
                new Node this, {self: url}
            relationships = data.relationships.map (url) =>
                new Relationship this, null, null, type, {self: url}

            # Return path
            path = new Path start, end, length, nodes, relationships
            return path

        catch error
            throw adjustError error

    # XXX this is actually a traverse, but in lieu of defining a non-trivial
    # traverse() method, exposing this for now for our simple use case.
    getRelationshipNodes: (type, _) ->

        # support passing in multiple types, as array
        types = if type instanceof Array then type else [type]

        try
            traverseURL = @_data['traverse']?.replace '{returnType}', 'node'

            if not traverseURL
                throw new Error 'Traverse not available.'

            resp = request.post
                url: traverseURL
                json:
                    'max depth': 1
                    'relationships': types.map (type) -> {'type': type}
            , _

            if resp.statusCode is 404
                throw new Error 'Node not found.'

            if resp.statusCode isnt 200
                throw new Error "Unrecognized response code: #{resp.statusCode}"

            #success
            data = JSON.parse resp.body
            return data.map (data) => new Node @db, data

        catch error
            throw adjustError error

    index: (index, key, value, _) ->
        try
            # TODO
            if not @exists
                throw new Error 'Node must exists before indexing properties'

            services = @db.getServices _

            encodedKey = encodeURIComponent key
            encodedValue = encodeURIComponent value
            url = "#{services.node_index}/#{index}/#{encodedKey}/#{encodedValue}"

            response = request.post
                url: url
                json: @self
            , _

            if response.statusCode isnt status.CREATED
                # database error
                throw new Error response.statusCode

            # success
            return

        catch error
            throw adjustError error
