request = require 'request'

# XXX helpers to wrap request's multiple callback values into one Streamline
# "return" value while preserving futures. for details, see this thread:
# http://groups.google.com/group/streamlinejs/browse_thread/thread/871fb5379bd4b65c
# request.___() now returns just "response" w/ an extra "body" property on it.
# TODO ideally this would be an automatic feature in streamline. working on it.

# note the "__wrap" prefix is needed for and special-cased by Streamline.
__wrapRequestCallback = (callback) ->
    (error, response, body) ->
        response?.body = body
        callback error, response
        return  # important. a rare time where this is actually needed.

# this wraps each of the request.___() methods to wrap the results as above.
for verb in ['get', 'post', 'put', 'del', 'head']
    do (verb) ->    # need closure: inner callback references outer origMethod
        origMethod = request[verb]
        request[verb] = (options, _) ->
            origMethod options, __wrapRequestCallback(_)

module.exports = request
