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
        node = new Node this,
            data: data

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


    getNodeById: (id, callback) ->
        @getServices (err, services) ->
            url = "#{services.node}/#{id}"
            getNode url, callback

    # Relationships
    createRelationship: (startNode, endNode, type, callback) ->
        # TODO: Implement


class PropertyContainer
    constructor: (db, data) ->
        @db = db

        @_data = data || {}
        @_data.self = data.self || null

        @getter 'self', -> @_data.self || null
        @getter 'exists', -> @_data.self?

        @getter 'data', -> @_data.data || null
        @setter 'data', (value) -> @_data.data = value

    getter: @__defineGetter__
    setter: @__defineSetter__


class Node extends PropertyContainer
    constructor: (db, data) ->
        super db, data

        @_modified = true

        @getter 'modified', -> @_modified

    save: (callback) ->
        # TODO: check for actual modification
        @_modified = true

        if @exists and @modified
            request.put
                uri: @self + '/properties'
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

    destroy: (callback) ->
        # TODO

class Relationship extends PropertyContainer
    constructor: (db, start, end, type, data) ->
        super db, data

        @_start = start
        @_end = end
        @_type = type || null

        @getter 'type', -> @_type || null

    load: (callback) ->
        # TODO

    save: (callback) ->
        # TODO

    destroy: (callback) ->
        # TODO

    createRelationshipTo: (otherNode, type, callback) ->
        # TODO

# Exports
exports.GraphDatabase = GraphDatabase
