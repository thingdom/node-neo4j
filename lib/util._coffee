request = require 'request'
URL = require 'url'

#-----------------------------------------------------------------------------
#
#  HTTP Basic Auth support
#
#-----------------------------------------------------------------------------

# wrapping request methods to support HTTP Basic Auth, since Neo4j doesn't
# preserve the username and password in the URLs! This code derived from:
# https://github.com/thingdom/node-neo4j/issues/7 (by @anatoliychakkaev)
# returns a minimal wrapper (HTTP methods only) around request so that each
# method ensures that URLs include HTTP Basic Auth usernames/passwords.
exports.wrapRequestForAuth = (url) ->
    # parse auth info, and short-circuit if we have none:
    auth = URL.parse(url).auth
    return request if not auth

    # updates the args to ensure that the URL arg has username/password:
    fixArgs = (args) ->
        # the URL may be the first arg alone, as a string, or an options obj:
        # update: it may also be called 'uri' instead of 'url'!
        if typeof args[0] is 'string'
            url = args[0]
        else
            url = args[0].url or args[0].uri

        if not url
            console.log 'UH OH:'
            console.log args

        # ensure auth info is included in the URL:
        url = URL.parse url
        if not url.auth
            # XXX argh, just setting url.auth isn't picked up by URL.format()!
            # it relies first on just url.host, so update that instead:
            # TODO account for case where url.auth is set, but different?
            url.host = "#{auth}@#{url.host}"
        url = URL.format url

        # then update the original args:
        if typeof args[0] is 'string'
            args[0] = url
        else
            args[0].url = args[0].uri = url

        return args

    # wrap each method to fix its args before calling real method:
    wrapper = {}
    for verb in ['get', 'post', 'put', 'del', 'head']
        do (verb) ->    # freaking closures!
            wrapper[verb] = (args...) ->
                request[verb].apply request, fixArgs args

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
        error.message = "Couldn’t reach database (connection refused)"

    return error

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
