## Node-Neo4j Tests

Many of these tests are written in [Streamline.js](https://github.com/Sage/streamlinejs) syntax, for convenience and robustness.

In a nutshell, instead of calling async functions with a callback (that takes an error and a result), we get to call them with an `_` parameter instead, and then pretend as if the functions are synchronous (*returning* their results and *throwing* any errors).

E.g. instead of writing tests like this:

```coffee
describe 'foo', ->
    it 'should bar', (done) ->
        db.foo (err, result) ->
            expect(err).to.not.exist()
            expect(result).to.equal 'bar'
            done()
```

We get to write tests like this:

```coffee
describe 'foo', ->
    it 'should bar', (_) ->
        result = db.foo _
        expect(result).to.equal 'bar'
```

This lets us write more concise tests that simultaneously test for errors more thoroughly. (If an async function "throws" an error, the test will fail.)
