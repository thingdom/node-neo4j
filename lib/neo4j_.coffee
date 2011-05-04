###

    Node driver for Neo4j

    Copyright 2011 Daniel Gasienica <daniel@gasienica.ch>
    Copyright 2011 Aseem Kishore <aseem.kishore@gmail.com>

    Licensed under the Apache License, Version 2.0 (the "License"); you may
    not use this file except in compliance with the License. You may obtain
    a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
    License for the specific language governing permissions and limitations
    under the License.

###

# TODO many of these functions take a callback but, in some cases, call the
# callback immediately (e.g. if a value is cached). we should probably make
# sure to always call callbacks asynchronously, to prevent race conditions.
# this can be done in Streamline syntax by adding one line before cases where
# we're returning immediately: process.nextTick _

status = require 'http-status'
request = require './request_'

util = require './util_'
adjustError = util.adjustError

PropertyContainer = require './PropertyContainer_'
Relationship = require './Relationship_'
Path = require './Path_'

class GraphDatabase
    constructor: (url) ->
        @url = url

        # Cache
        @_root = null
        @_services = null

    # Database
    purgeCache: ->
        @_root = null
        @_services = null

    getRoot: (_) ->
        if @_root?
            return @_root
        
        try    
            response = request.get {url: @url}, _
            
            if response.statusCode isnt status.OK
                throw response.statusCode
            
            @_root = JSON.parse response.body
            return @_root

        catch error
            throw adjustError error

    getServices: (_) ->
        if @_services?
            return @_services
        
        try
            root = @getRoot _
            response = request.get {url: root.data}, _
            
            if response.statusCode isnt status.OK
                throw response.statusCode
            
            @_services = JSON.parse response.body
            return @_services

        catch error
            throw adjustError error

    # Nodes
    createNode: (data) ->
        data = data || {}
        node = new Node this,
            data: data
        return node

    getNode: (url, _) ->
        try
            response = request.get {url: url}, _
            
            if response.statusCode isnt status.OK
                # TODO: Handle 404
                throw response
            
            node = new Node this, JSON.parse response.body
            return node

        catch error
            throw adjustError error

    getIndexedNode: (index, property, value, _) ->
        try
            nodes = @getIndexedNodes index, property, value, _

            node = null
            if nodes and nodes.length > 0
                node = nodes[0]
            return node

        catch error
            throw adjustError error

    getIndexedNodes: (index, property, value, _) ->
        try
            services = @getServices _
            
            key = encodeURIComponent property
            val = encodeURIComponent value
            url = "#{services.node_index}/#{index}/#{key}/#{val}"
            
            response = request.get {url: url}, _
            
            if response.statusCode is status.NOT_FOUND
                # Node not found
                return null
            
            if response.statusCode isnt status.OK
                # Database error
                throw response.statusCode
            
            # Success
            nodeArray = JSON.parse response.body
            nodes = nodeArray.map (node) =>
                new Node this, node
            return nodes

        catch error
            throw adjustError error

    getNodeById: (id, _) ->
        services = @getServices _
        url = "#{services.node}/#{id}"
        @getNode url, _

    # Relationships
    createRelationship: (startNode, endNode, type, _) ->
        # TODO: Implement

    getRelationship: (url, _) ->
        try
            response = request.get {url: url}, _
            
            if response.statusCode isnt status.OK
                # TODO: Handle 404
                throw response
            
            data = JSON.parse response.body
            
            # Construct relationship
            start = new Node this, {self: data.start}
            end = new Node this, {self: data.end}
            type = data.type
            relationship = new Relationship this, start, end, type, data
            
            return relationship

        catch error
            throw adjustError error

    getRelationshipById: (id, _) ->
        services = @getServices _
        # FIXME: Neo4j doesn't expose the path to relationships
        relationshipURL = services.node.replace('node', 'relationship')
        url = "#{relationshipURL}/#{id}"
        @getRelationship url, _


class Node extends PropertyContainer
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

                # success
                return
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

                # success
                @_data = JSON.parse response.body
                return

        catch error
            throw adjustError error

    delete: (_) ->
        if not @exists
            return
        
        try
            response = request.del {uri: @self}, _
            
            if response.statusCode isnt status.NO_CONTENT
                # database error
                message = ''
                switch response.statusCode
                    when status.NOT_FOUND
                        message = 'Node not found'
                    # TODO: handle node with relationships
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

        # support passing in multiple types, as array
        types = if type instanceof Array then type else [type]

        try
            prefix = @_data["#{direction}_typed_relationships"]
            getRelationshipsURL = prefix?.replace '{-list|&|types}', types.join '&'
    
            if not getRelationshipsURL
                throw new Error 'Relationships not available.'
    
            resp = request.get {url: getRelationshipsURL}, _
            
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


# Exports
exports.GraphDatabase = GraphDatabase
