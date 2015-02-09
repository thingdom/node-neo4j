errors = require './errors'
utils = require './utils'

# This value is used to construct a Date instance, and unfortunately, neither
# Infinity nor Number.MAX_VALUE are valid Date inputs. There's also no simple
# max value for Dates either (http://stackoverflow.com/a/11526569/132978),
# so we arbitrarily do one year ahead. Hopefully this doesn't matter.
FAR_FUTURE_MS = Date.now() + 1000 * 60 * 60 * 24 * 365


# http://neo4j.com/docs/stable/rest-api-transactional.html
module.exports = class Transaction

    constructor: (@_db) ->
        @_id = null
        @_expires = null
        @_pending = false
        @_committed = false
        @_rolledback = false

    Object.defineProperty @::, 'expiresAt',
        enumerable: true
        get: ->
            if @_expires
                new Date @_expires
            else
                # This transaction hasn't been created yet, so far future:
                new Date FAR_FUTURE_MS

    Object.defineProperty @::, 'expiresIn',
        enumerable: true
        get: ->
            if @_expires
                @expiresAt - (new Date)
            else
                # This transaction hasn't been created yet, so far future.
                # Unlike for the Date instance above, we can be less arbitrary;
                # hopefully it's never a problem to return Infinity here.
                Infinity

    #
    # The state of this transaction. Returns one of the following values:
    #
    # - open
    # - pending (a request is in progress)
    # - committed
    # - rolled back
    # - expired
    #
    # TODO: Should we make this an enum? Or constants?
    #
    Object.defineProperty @::, 'state',
        get: -> switch
            # Order matters here.
            #
            # E.g. a request could have been made just before the expiry time,
            # and we won't know the new expiry time until the server responds.
            #
            # TODO: The server could also receive it just *after* the expiry
            # time, which'll cause it to return an unhelpful `UnknownId` error;
            # should we handle that edge case in our `cypher` callback below?
            #
            when @_pending then 'pending'
            when @_committed then 'committed'
            when @_rolledback then 'rolled back'
            when @expiresIn <= 0 then 'expired'
            else 'open'

    cypher: (opts={}, cb) ->
        # Check predictable error cases to provide better messaging sooner.
        # All of these are `ClientErrors` within the `Transaction` category.
        # http://neo4j.com/docs/stable/status-codes.html#_status_codes
        errMsg = switch @state
            when 'pending'
                # This would otherwise throw a `ConcurrentRequest` error.
                'A request within this transaction is currently in progress.
                    Concurrent requests within a transaction are not allowed.'
            when 'expired'
                # This would otherwise throw an `UnknownId` error.
                'This transaction has expired.
                    You can get the expiration time of a transaction through its
                    `expiresAt` (Date) and `expiresIn` (ms) properties.
                    To prevent a transaction from expiring, execute any action
                    or call `renew` before the transaction expires.'
            when 'committed'
                # This would otherwise throw an `UnknownId` error.
                'This transaction has been committed.
                    Transactions cannot be reused; begin a new one instead.'
            when 'rolled back'
                # This would otherwise throw an `UnknownId` error.
                'This transaction has been rolled back.
                    Transactions get automatically rolled back on any
                    DatabaseErrors, as well as any errors during a commit.
                    That includes auto-commit queries (`{commit: true}`).
                    Transactions cannot be reused; begin a new one instead.'

        if errMsg
            # TODO: Should we callback this error instead? (And if so, should we
            # `process.nextTick` that call?)
            # I *think* that these cases are more likely to be code bugs than
            # legitimate runtime errors, so the benefit of throwing sync'ly is
            # fail-fast behavior, and more helpful stack traces.
            throw new errors.ClientError errMsg

        # The only state we should be in at this point is 'open'.
        @_pending = true
        @_db.cypher opts, (err, results) =>
            @_pending = false

            # If this transaction still exists, no state changes for us:
            if @_id
                return cb err, results

            # Otherwise, this transaction was destroyed -- either committed or
            # rolled back -- so update our state accordingly.
            # Much easier to derive whether committed than whether rolled back,
            # because commits can only happen when explicitly requested.
            if opts.commit and not err
                @_committed = true
            else
                @_rolledback = true

            cb err, results
        , @

    commit: (cb) ->
        @cypher {commit: true}, cb

    rollback: (cb) ->
        @cypher {rollback: true}, cb

    renew: (cb) ->
        @cypher {}, cb

    #
    # Updates this Transaction instance with data from the given transactional
    # endpoint response.
    #
    _updateFromResponse: (resp) ->
        if not resp
            throw new Error 'Unexpected: no transactional response!'

        {body, headers, statusCode} = resp
        {transaction} = body

        if not transaction
            # This transaction has been destroyed (either committed or rolled
            # back). Our state will get updated in the `cypher` callback above.
            @_id = @_expires = null
            return

        # Otherwise, this transaction exists.
        # The returned object always includes an updated expiry time...
        @_expires = new Date transaction.expires

        # ...but only includes the URL (from which we can parse its ID)
        # the first time, via a Location header for a 201 Created response.
        # We can short-circuit if we already have our ID.
        return if @_id

        if statusCode isnt 201
            throw new Error 'Unexpected: transaction returned by Neo4j,
                but it was never 201 Created, so we have no ID!'

        if not transactionURL = headers['location']
            throw new Error 'Unexpected: transaction response is 201 Created,
                but with no Location header!'

        @_id = utils.parseId transactionURL
