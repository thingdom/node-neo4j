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

status = require 'http-status'
request = require 'request'

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

    getRoot: (callback) ->
        if @_root?
            callback null, @_root
        else
            request.get
                url: @url
            , (error, response, body) ->
                if error
                    handleError callback, error
                else if response.statusCode isnt status.OK
                    handleError callback, response.statusCode
                else
                    @_root = JSON.parse body
                    callback null, @_root

    getServices: (callback) ->
        if @_services?
            callback null, @_services
        else
            @getRoot (err, root) ->
                if err
                    handleError callback, err
                else
                    request.get
                        url: root.data
                    , (error, response, body) ->
                        if error
                            handleError callback, error
                        else if response.statusCode isnt status.OK
                            handleError callback, response.statusCode
                        else
                            @_services = JSON.parse body
                            callback null, @_services

    # Nodes
    createNode: (data) ->
        data = data || {}
        node = new Node this,
            data: data
        return node

    getNode: (url, callback) ->
        request.get
            url: url
        , (error, response, body) =>    # note fat arrow to preserve 'this'!
            if error
                handleError callback, error
            else if response.statusCode isnt status.OK
                # TODO: Handle 404
                callback response
            else
                node = new Node this, JSON.parse body
                callback null, node

    getIndexedNode: (index, property, value, callback) ->
        @getIndexedNodes index, property, value,
            (err, nodes) =>
                if err
                    handleError callback, err
                else
                    node = null
                    if nodes and nodes.length > 0
                        node = nodes[0]
                    callback null, node

    getIndexedNodes: (index, property, value, callback) ->
        @getServices (err, services) =>
            if err
                return handleError callback, err

            key = encodeURIComponent property
            val = encodeURIComponent value
            url = "#{services.node_index}/#{index}/#{key}/#{val}"

            request.get
                url: url
            , (error, response, body) =>
                if error
                    # Internal error
                    handleError callback, error
                else if response.statusCode is status.NOT_FOUND
                    # Node not found
                    callback null, null
                else if response.statusCode isnt status.OK
                    # Database error
                    handleError callback, response.statusCode
                else
                    # Success
                    nodeArray = JSON.parse body
                    nodes = nodeArray.map (node) =>
                        new Node this, node
                    callback null, nodes


    getNodeById: (id, callback) ->
        @getServices (err, services) =>
            url = "#{services.node}/#{id}"
            @getNode url, callback

    # Relationships
    createRelationship: (startNode, endNode, type, callback) ->
        # TODO: Implement

    getRelationship: (url, callback) ->
        request.get
            url: url
        , (error, response, body) =>
            if error
                handleError callback, error
            else if response.statusCode isnt status.OK
                # TODO: Handle 404
                callback response
            else
                data = JSON.parse body

                # Construct relationship
                start = new Node this, {self: data.start}
                end = new Node this, {self: data.end}
                type = data.type
                relationship = new Relationship this, start, end, type, data

                callback null, relationship

    getRelationshipById: (id, callback) ->
        @getServices (err, services) =>
            # FIXME: Neo4j doesn't expose the path to relationships
            relationshipURL = services.node.replace('node', 'relationship')
            url = "#{relationshipURL}/#{id}"
            @getRelationship url, callback


class PropertyContainer
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


class Node extends PropertyContainer
    constructor: (db, data) ->
        super db, data

    save: (callback) ->
        # TODO: check for actual modification
        if @exists
            request.put
                uri: @self + '/properties'
                json: @data
            , (error, response, body) =>
                if error
                    # internal error
                    handleError callback, error
                else if response.statusCode isnt status.NO_CONTENT
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.BAD_REQUEST then message = 'Invalid data sent'
                        when status.NOT_FOUND then message = 'Node not found'
                    e = new Error message
                    handleError callback, error
                else
                    # success
                    callback null, this
        else
            @db.getServices (error, services) =>
                if error
                    # internal error
                    handleError callback, error
                else
                    request.post
                        uri: services.node
                        json: @data
                    , (error, response, body) =>
                        if error
                            # internal error
                            handleError callback, error
                        else if response.statusCode isnt status.CREATED
                            # database error
                            message = ''
                            switch response.statusCode
                                when status.BAD_REQUEST then message = 'Invalid data sent'
                            callback new Error message
                        else
                            # success
                            @_data = JSON.parse body
                            callback null, this

    delete: (callback) ->
        if not @exists
            callback null
        else
            request.del
                uri: @self
            , (error, response, body) =>
                if error
                    # internal error
                    handleError callback, error
                else if response.statusCode isnt status.NO_CONTENT
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.NOT_FOUND
                            message = 'Node not found'
                        # TODO: handle node with relationships
                        when status.CONFLICT
                            message = 'Node could not be deleted (still has relationships?)'
                    callback new Error message
                else
                    # success
                    callback null

    # Alias
    del: @::delete

    # TODO why no createRelationshipFrom()? this actually isn't there in the
    # REST API, but we might be able to support it oursleves.
    createRelationshipTo: (otherNode, type, data, callback) ->
        # ensure this node exists
        # ensure otherNode exists
        # create relationship
        createRelationshipURL = @_data['create_relationship']
        otherNodeURL = otherNode.self
        if createRelationshipURL? and otherNodeURL
            request.post
                url: createRelationshipURL
                json:
                    to: otherNodeURL
                    data: data
                    type: type
                (error, response, body) =>
                    if error
                        # internal error
                        handleError callback, error
                    else if response.statusCode isnt status.CREATED
                        # database error
                        message = ''
                        switch response.statusCode
                            when status.BAD_REQUEST
                                message = 'Invalid data sent'
                            when status.CONFLICT
                                message = '"to" node, or the node specified by the URI not found'
                        callback new Error message
                    else
                        # success
                        data = JSON.parse body
                        relationship = new Relationship @db, this, otherNode, type, data
                        callback null, relationship
        else
            callback new Error 'Failed to create relationship'

    # TODO support passing direction also? the REST API does, but having to
    # specify 'in', 'out' or 'all' here would be a bad string API. maybe add
    # getRelationshipsTo() and getRelationshipsFrom()?
    # TODO support passing in no type, e.g. for all types?
    # TODO to be consistent with the REST and Java APIs, this returns an array
    # of all returned relationships. it would certainly be more user-friendly
    # though if it returned a dictionary of relationships mapped by type, no?
    _getRelationships: (direction, type, callback) ->
        # Method overload: No type specified
        if typeof type is 'function'
            callback = type
            type = []

        # support passing in multiple types, as array
        types = if type instanceof Array then type else [type]

        prefix = @_data["#{direction}_typed_relationships"]
        getRelationshipsURL = prefix?.replace '{-list|&|types}', types.join '&'

        if not getRelationshipsURL
            callback new Error 'Relationships not available.'
            return

        request.get
            url: getRelationshipsURL
            (err, resp, body) =>
                if err
                    handleError callback, err
                    return
                if resp.statusCode is status.NOT_FOUND
                    callback new Error 'Node not found.'
                    return
                if resp.statusCode isnt status.OK
                    callback new Error "Unrecognized response code: #{resp.statusCode}"
                    return
                # success
                data = JSON.parse body
                relationships = data.map (data) =>
                    # XXX constructing a fake Node object for other node
                    if @self is data.start
                        start = this
                        end = new Node @db, {self: data.end}
                    else
                        start = new Node @db, {self: data.start}
                        end = this
                    return new Relationship @db, start, end, type, data
                callback null, relationships

        # this is to support streamline futures in the future (pun not intended)
        return

    # TODO to be consistent with the REST and Java APIs, this returns an array
    # of all returned relationships. it would certainly be more user-friendly
    # though if it returned a dictionary of relationships mapped by type, no?
    getRelationships: (type, callback) ->
        @all type, callback

    outgoing: (type, callback) ->
        @_getRelationships 'outgoing', type, callback

    incoming: (type, callback) ->
        @_getRelationships 'incoming', type, callbackk

    all: (type, callback) ->
        @_getRelationships 'all', type, callback

    path: (to, type, direction, maxDepth=1, algorithm='shortestPath', callback) ->
        pathURL = "#{@self}/path"
        data =
            to: to.self
            relationships:
                type: type
                direction: direction
            max_depth: maxDepth
            algorithm: algorithm

        request.post
            url: pathURL
            json: data
            (err, res, body) =>
                if err
                    handleError callback, err
                else if res.statusCode is status.NOT_FOUND
                    # Empty path
                    callback null, null
                else if res.statusCode isnt status.OK
                    callback new Error "Unrecognized response code: #{res.statusCode}"
                else
                    # Parse result
                    data = JSON.parse body

                    start = new Node this, {self: data.start}
                    end = new Node this, {self: data.end}
                    length = data.length
                    nodes = data.nodes.map (url) =>
                        new Node this, {self: url}
                    relationships = data.relationships.map (url) =>
                        new Relationship this, null, null, type, {self: url}

                    # Return path
                    path = new Path start, end, length, nodes, relationships
                    callback null, path

    # XXX this is actually a traverse, but in lieu of defining a non-trivial
    # traverse() method, exposing this for now for our simple use case.
    getRelationshipNodes: (type, callback) ->

        # support passing in multiple types, as array
        types = if type instanceof Array then type else [type]

        traverseURL = @_data['traverse']?.replace '{returnType}', 'node'

        if not traverseURL
            callback new Error 'Traverse not available.'
            return

        request.post
            url: traverseURL
            json:
                'max depth': 1
                'relationships': types.map (type) -> {'type': type}
            , (err, resp, body) =>
                if err
                    handleError callback, err
                    return
                if resp.statusCode is 404
                    callback new Error 'Node not found.'
                    return
                if resp.statusCode isnt 200
                    callback new Error "Unrecognized response code: #{resp.statusCode}"
                    return
                #success
                data = JSON.parse body
                callback null, data.map (data) => new Node @db, data
                return

    index: (index, key, value, callback) ->
        # TODO
        if not @exists
            error = new Error 'Node must exists before indexing properties'
            return handleError callback, error

        @db.getServices (error, services) =>
            if error
                return handleError callback, error
            encodedKey = encodeURIComponent key
            encodedValue = encodeURIComponent value
            url = "#{services.node_index}/#{index}/#{encodedKey}/#{encodedValue}"
            request.post
                url: url
                json: @self
                , (error, response, body) ->
                    if error
                        # internal error
                        handleError callback, error
                    else if response.statusCode isnt status.CREATED
                        # database error
                        callback new Error response.statusCode
                    else
                        # success
                        callback null


class Relationship extends PropertyContainer
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

    save: (callback) ->
        # TODO: check for actual modification
        if @exists
            request.put
                uri: @self + '/properties'
                json: @data
            , (error, response, body) =>
                if error
                    # internal error
                    handleError callback, error
                else if response.statusCode isnt status.NO_CONTENT
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.BAD_REQUEST
                            message = 'Invalid data sent'
                        when status.NOT_FOUND
                            message = 'Relationship not found'
                    callback new Error message
                else
                    # success
                    callback null, this

    delete: (callback) ->
        if not @exists
            callback null
        else
            request.del
                uri: @self
            , (error, response, body) =>
                if error
                    # internal error
                    handleError callback, error
                else if response.statusCode isnt status.NO_CONTENT
                    # database error
                    message = ''
                    switch response.statusCode
                        when status.NOT_FOUND
                            message = 'Relationship not found'
                    e = new Error message
                    callback e
                else
                    # success
                    callback null
    # Alias
    del: @::delete


class Path
    constructor: (start, end, length, nodes, relationships) ->
        @_start = start
        @_nodes = nodes
        @_length = length
        @_relationships = relationships
        @_end = end

        @getter 'start', -> @_start || null
        @getter 'end', -> @_end || null
        @getter 'length', -> @_length || 0
        @getter 'nodes', -> @_nodes || []
        @getter 'relationships', -> @_relationships || []

    getter: @__defineGetter__
    setter: @__defineSetter__


# Exports
exports.GraphDatabase = GraphDatabase

#-----------------------------------------------------------------------------
#
#  Errors
#
#-----------------------------------------------------------------------------

handleError = (callback, error) ->
    if error.errno is 61 # process.ECONNREFUSED
        error.message = "Couldn't reach database (Connection refused)"
    callback error

#-----------------------------------------------------------------------------
#
#  Serialization / Deserialization
#
#-----------------------------------------------------------------------------

exports.serialize = (o, separator) ->
    JSON.stringify flatten(o, separator)


exports.deserialize = (o, separator) ->
    unflatten JSON.parse(o), separator


flatten = (o, separator, result, prefix) ->
    separator = separator || '.'
    result = result || {}
    prefix = prefix || ''

    # only proceed if argument o is a complex object
    if typeof o isnt 'object'
        return o

    for key in Object.keys o
        value = o[key]
        if typeof value != 'object'
            result[prefix + key] = value
        else
            flatten(value, separator, result, key + separator)

    return result


unflatten = (o, separator, result) ->
    separator = separator || '.'
    result = result || {}

    # only proceed if argument o is a complex object
    if typeof o isnt 'object'
        return o

    for key in Object.keys o
        value = o[key]
        separatorIndex = key.indexOf separator
        if separatorIndex == -1
            result[key] = value
        else
            keys = key.split separator
            target = result
            numKeys = keys.length
            for i in [0..(numKeys - 2)]
                currentKey = keys[i]
                if target[currentKey] == undefined
                    target[currentKey] = {}
                target = target[currentKey]
            lastKey = keys[numKeys - 1]
            target[lastKey] = value

    return result
