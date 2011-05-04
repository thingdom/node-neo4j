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
Node = require './Node_'

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


# Exports
exports.GraphDatabase = GraphDatabase
