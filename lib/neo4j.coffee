###

    Node driver for Neo4j

    Copyright 2011 Daniel Gasienica <daniel@gasienica.ch>

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

request = require 'request'
Futures = require 'futures'


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
            return callback null, @_root
        else
            request.get
                url: @url
            , (error, response, body) ->
                if error
                    callback error, null
                else if response.statusCode isnt 200
                    callback response.statusCode, null
                else
                    @_root = JSON.parse body
                    callback null, @_root

    getServices: (callback) ->
        if @_services?
            return callback null, @_services
        else
            @getRoot (err, root) ->
                if err
                    return callback err null
                request.get
                    url: root.data
                , (error, response, body) ->
                    if error
                        callback error, null
                    else if response.statusCode isnt 200
                        callback response.statusCode, null
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
        , (error, response, body) ->
            if error
                return callback(error, null)

            if response.statusCode isnt 200
                # TODO: Handle 404
                return callback response, null

            node = new Node this, JSON.parse body
            callback null, node

    getIndexedNode: (index, property, value, callback) ->
        @getServices (err, services) =>
            if err
                return callback err, null

            key = encodeURIComponent property
            val = encodeURIComponent value
            url = "#{services.node_index}/#{index}/#{key}/#{val}"

            request.get
                url: url
            , (error, response, body) =>
                if error
                    # Internal error
                    callback(error, null)
                else if response.statusCode is 404
                    # Node not found
                    callback null, null
                else if response.statusCode isnt 200
                    # Database error
                    callback response.statusCode, null
                else
                    # Success
                    nodes = JSON.parse body
                    node = new Node this, nodes[0]
                    callback null, node


    getNodeById: (id, callback) ->
        @getServices (err, services) =>
            url = "#{services.node}/#{id}"
            @getNode url, callback

    # Relationships
    createRelationship: (startNode, endNode, type, callback) ->
        # TODO: Implement


class PropertyContainer
    constructor: (db, data) ->
        @db = db

        @_data = data || {}
        @_data.self = data?.self || null

        @getter 'self', -> @_data.self || null
        @getter 'exists', -> @_data.self?
        @getter 'id', ->
            if not @exists
                return null
            if not @_id?
                match = /(?:node|relationship)\/(\d+)$/.exec @self
                @_id = parseInt match[1]
            return @_id

        @getter 'data', -> @_data.data || null
        @setter 'data', (value) -> @_data.data = value

    getter: @__defineGetter__
    setter: @__defineSetter__


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
                    callback error, null
                else if response.statusCode isnt 204
                    # database error
                    message = ''
                    switch response.statusCode
                        when 400 then message = 'Invalid data sent'
                        when 404 then message = 'Node not found'
                    e = new Error message
                    callback error, null
                else
                    # success
                    callback null, this
        else
            @db.getServices (error, services) =>
                if error
                    # internal error
                    callback error, null
                else
                    request.post
                        uri: services.node
                        json: @data
                    , (error, response, body) =>
                        if error
                            # internal error
                            callback error, null
                        else if response.statusCode isnt 201
                            # database error
                            message = ''
                            switch response.statusCode
                                when 400 then message = 'Invalid data sent'
                            callback new Error message, null
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
                    callback error
                else if response.statusCode isnt 204
                    # database error
                    message = ''
                    switch response.statusCode
                        when 404 then message = 'Node not found'
                        # TODO: handle node with relationships
                        when 409 then message = 'Node could not be deleted (still has relationships?)'
                    callback new Error message
                else
                    # success
                    callback null

    # Alias
    del: @delete

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
                (error, response, body) ->
                    if error
                        # internal error
                        callback error, null
                    else if response.statusCode isnt 201
                        # database error
                        message = ''
                        switch response.statusCode
                            when 400 then message = 'Invalid data sent'
                            when 409 then message = '"to" node, or the node specified by the URI not found'
                        callback new Error message, null
                    else
                        # success
                        data = JSON.parse body
                        relationship = new Relationship @db, this, otherNode, type, data
                        callback null, relationship
        else
            callback new Error 'Failed to create relationship', null


class Relationship extends PropertyContainer
    constructor: (db, start, end, type, data) ->
        super db, data

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
                    callback error, null
                else if response.statusCode isnt 204
                    # database error
                    message = ''
                    switch response.statusCode
                        when 400 then message = 'Invalid data sent'
                        when 404 then message = 'Relationship not found'
                    callback new Error message, null
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
                    callback error
                else if response.statusCode isnt 204
                    # database error
                    message = ''
                    switch response.statusCode
                        when 404 then message = 'Relationship not found'
                    e = new Error message
                    callback e
                else
                    # success
                    callback null
    # Alias
    del: @delete

# Exports
exports.GraphDatabase = GraphDatabase

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

    for key in o
        if o.hasOwnProperty key
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

    for key in o
        if o.hasOwnProperty key
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
