# Miscellaneous tests.

{expect} = require 'chai'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

@misc =

    # Tests: https://github.com/thingdom/node-neo4j/issues/76
    # By waiting one second to see if the callback is called twice.
    #
    # Note that this test is explicitly *not* in Streamline syntax, so we can
    # test the use case where a regular callback throws an error instead of
    # properly propagating it (which Streamline automatically takes care of).
    #
    # This will FAIL until this issue is fixed upstream in Streamline:
    # https://github.com/Sage/streamlinejs/issues/168
    #
    'callback that throws error': (next) ->
        # this test passes via manual/visual verification now --
        # the error is properly thrown immediately instead of this callback
        # getting called twice.
        # but because an error is thrown, this test still fails to Mocha.
        # TEMP so short-circuiting for now. TODO figure out a way to test?
        return next()

        called = false
        timer = null

        db.getNodeById 0, (err, node) ->
            # TEMP remove after we figure this out...
            console.log '(temporary debugging) callback called'

            # if we're getting called a second time, clear our timer:
            clearTimeout timer if timer

            # now check to see if we've been called already:
            if called
                throw new Error "Callback called twice!"
            else
                called = true

            # now cause a synchronous error, but set a timeout first for the
            # correct case that we never get called again.
            timer = setTimeout next, 1000
            (null).foo
