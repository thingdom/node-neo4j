lib = require '../package.json'
request = require 'request'
URL = require 'url'

#-----------------------------------------------------------------------------
#
#  HTTP Requests
#
#-----------------------------------------------------------------------------

USER_AGENT = "node-neo4j/#{lib.version}"

# wrapping request methods to:
# - support HTTP Basic Auth, since Neo4j deosn't preserve auth info in URLs.
# - add a user-agent header with this library's info.
# - auto-set all requests and auto-parse all responses as JSON.
# returns a minimal wrapper (HTTP methods only) around request.
exports.wrapRequest = ({url, proxy}) ->
    # default request opts where possible (no headers since the whole headers
    # collection will be overridden if any one header is provided):
    req = request.defaults
        json: true
        proxy: proxy

    # parse auth info:
    auth = URL.parse(url).auth

    # helper function to modify args to request where defaults not possible:
    modifyArgs = (args) ->
        # the main arg may be just a string URL, or an options object.
        # normalize it to an options object, and derive URL:
        arg = args[0]
        opts =
            if typeof arg is 'string' then {url: arg}
            else arg
        url = opts.url or opts.uri

        # ensure auth info is included in the URL:
        url = URL.parse url
        if not url.auth
            # XXX argh, just setting url.auth isn't picked up by URL.format()!
            # it relies first on just url.host, so update that instead:
            # TODO account for case where url.auth is set, but different?
            url.host = "#{auth}@#{url.host}"
        url = URL.format url

        # now update the url arg and other options:
        opts.url = opts.uri = url
        opts.headers or= {}     # preserve existing headers
        opts.headers['User-Agent'] = USER_AGENT

        # finally, update and return the modified args:
        args[0] = opts
        return args

    # wrap each method to modify its args before calling that method:
    wrapper = {}
    for verb in ['get', 'post', 'put', 'del', 'head']
        do (verb) ->    # freaking closures!
            wrapper[verb] = (args...) ->
                req[verb].apply req, modifyArgs args

    # and return this set of wrapped methods:
    return wrapper

#-----------------------------------------------------------------------------
#
#  Errors
#
#-----------------------------------------------------------------------------

exports.adjustError = (error) ->
    # Neo4j server error (error is a response object)
    if error.statusCode
        serverError = error.body or
            message: 'Unknown Neo4j error.'

        # in some cases, node-request hasn't parsed response JSON yet, so do.
        # XXX protect against neo4j incorrectly sending HTML instead of JSON.
        if typeof serverError is 'string'
            try
                serverError = JSON.parse serverError

        error = new Error
        error.message = serverError.message or serverError

    if typeof error isnt 'object'
        error = new Error error

    # XXX Node 0.6 seems to break error.errno -- doesn't match constants
    # anymore -- so don't use it! instead, use the string code directly.
    # see: http://stackoverflow.com/a/9254101/132978
    if error.code is 'ECONNREFUSED'
        error.message = "Couldn't reach database (connection refused)"

    return error

#-----------------------------------------------------------------------------
#
#  Serialization / Deserialization
#
#-----------------------------------------------------------------------------

# deep inspects the given value -- object, array, primitive, whatever -- and
# transforms it or its subvalues into the appropriate Node/Relationship/Path
# instances. returns the transformed value.
exports.transform = transform = (val, db) ->
    # arrays should be recursed:
    if val instanceof Array
        return val.map (val) ->
            transform val, db

    # ignore non-neo4j objects:
    # (XXX this means we aren't recursing hash maps for now! fine for now.)
    if not val or typeof val isnt 'object' or not val.self
        return val

    # inline requires to prevent circular dependencies:
    Path = require './Path'
    Node = require './Node'
    Relationship = require './Relationship'

    # relationships have a type property:
    if typeof val.type is 'string'
        return new Relationship db, val

    # paths have nodes and relationships:
    # (XXX this doesn't handle fullpaths, but we don't return those yet.)
    if val.nodes and val.relationships
        # XXX the path's nodes and relationships are just URLs for now!
        start = new Node db, {self: val.start}
        end = new Node db, {self: val.end}
        length = val.length
        nodes = val.nodes.map (url) ->
            new Node db, {self: url}
        relationships = val.relationships.map (url) ->
            new Relationship db, {self: url}

        return new Path start, end, length, nodes, relationships

    # the only other type of neo4j object is a node:
    else
        return new Node db, val

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
