## Node-Neo4j Tests

Many of these tests are written in [Streamline.js](https://github.com/Sage/streamlinejs) syntax, for convenience and robustness.

In a nutshell, instead of calling async functions with a callback (that takes an error and a result), we get to call them with an `_` parameter instead, and then pretend as if the functions are synchronous (*returning* their results and *throwing* any errors).

E.g. instead of writing tests like this:

```coffee
it 'should get foo then set bar', (done) ->
    db.getFoo (err, foo) ->
        expect(err).to.not.exist()
        expect(foo).to.be.a 'number'

        db.setBar foo, (err, bar) ->
            expect(err).to.not.exist()
            expect(bar).to.equal foo

            done()
```

We get to write tests like this:

```coffee
it 'should get foo then set bar', (_) ->
    foo = db.getFoo _
    expect(foo).to.be.a 'number'

    bar = db.setBar foo, _
    expect(bar).to.equal foo
```

This lets us write more concise tests that simultaneously test for errors more thoroughly. (If an async function "throws" an error, the test will fail.)
