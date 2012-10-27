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
# - specify that Neo4j should stream its JSON responses.
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
        if url.auth isnt auth
            # XXX argh, just setting url.auth isn't picked up by URL.format()!
            # it relies first on just url.host, so update that instead:
            url.host = "#{auth}@#{url.host}"
        url = URL.format url

        # now update the url arg and other options:
        opts.url = opts.uri = url
        opts.headers or= {}     # preserve existing headers
        opts.headers['User-Agent'] = USER_AGENT
        opts.headers['X-Stream'] = true

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
            message: "Unknown Neo4j error (status #{error.statusCode})."

        # in some cases, node-request hasn't parsed response JSON yet, so do.
        # XXX protect against neo4j incorrectly sending HTML instead of JSON.
        if typeof serverError is 'string'
            try
                serverError = JSON.parse serverError

        # also in some cases, the response body is indeed an error object, but
        # it's a Neo4j exception without a message:
        if serverError?.exception and not serverError.message
            serverError.message = """
                Neo4j #{serverError.exception}: #{
                    JSON.stringify serverError.stacktrace or [], null, 2
                }
            """

        error = new Error
        error.message = serverError.message or serverError

    if typeof error isnt 'object'
        error = new Error error

    # XXX Node 0.6 seems to break error.errno -- doesn't match constants
    # anymore -- so don't use it! instead, use the string code directly.
    # see: http://stackoverflow.com/a/9254101/132978
    if error.code is 'ECONNREFUSED'
        error.message = "Couldn't reach database (connection refused)."

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
    # ignore non-objects:
    if not val or typeof val isnt 'object'
        return val

    # arrays should be recursed:
    if val instanceof Array
        return val.map (val) ->
            transform val, db

    # inline requires to prevent circular dependencies:
    Path = require './Path'
    Node = require './Node'
    Relationship = require './Relationship'

    # we want to transform neo4j objects but also recurse non-neo4j objects,
    # since they may be maps/dictionaries. so we detect neo4j objects via
    # duck typing, and assume all other objects are maps. helper:
    hasProps = (props) ->
        for type, keys of props
            for key in keys.split '|'
                if typeof val[key] isnt type
                    return false
        return true

    # nodes:
    if hasProps {string: 'self|traverse', object:'data'}
        return new Node db, val

    # relationships:
    if hasProps {string: 'self|type|start|end', object:'data'}
        return new Relationship db, val

    # paths:
    # XXX this doesn't handle fullpaths for now, but we don't return those
    # anywhere yet AFAIK. TODO detect and support fullpaths too?
    if hasProps {string: 'start|end', number: 'length', object:'nodes|relationships'}
        # XXX the path's nodes and relationships are just URLs for now!
        start = new Node db, {self: val.start}
        end = new Node db, {self: val.end}
        length = val.length
        nodes = val.nodes.map (url) ->
            new Node db, {self: url}
        relationships = val.relationships.map (url) ->
            new Relationship db, {self: url}

        return new Path start, end, length, nodes, relationships

    # all other objects -- treat as maps:
    else
        map = {}
        for key, subval of val
            map[key] = transform subval, db
        return map

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
