## Issues

Bug reports and feature requests are always welcome via [GitHub Issues](https://github.com/thingdom/node-neo4j/issues). General questions and troubleshooting are better served by the [mailing list](https://groups.google.com/group/node-neo4j) and [Stack Overflow](http://stackoverflow.com/questions/ask?tags=node.js,neo4j).

For bug reports, please try to include:

- Neo4j version (`curl -s localhost:7474/db/data/ | grep version`)
- Node.js version (`node --version`)
- node-neo4j version (`npm ls neo4j`)
- npm version (`npm --version`)
- Example code, if possible (pro tip: [create a gist](https://gist.github.com/) if there's a lot)

For feature requests, real-world use cases are always helpful.


## Pull Requests

If you're comfortable rolling up your sleeves and contributing code (instructions below), great! Fork this repo, start a new branch, and pull request away, but please follow these guidelines:

- Follow the existing code style. (We use [CoffeeLint](http://coffeelint.org/) to check it.) `npm run lint` should continue to pass.

- Add or update tests as appropriate. (You can look at the existing tests for reference.) `npm test` should continue to pass.

- Add or update documentation similarly. But don't stress too much about it; we'll likely polish documentation ourselves before release anyway.

- If this main repo's `master` branch has moved forward since you began, do merge the latest changes into your branch (or rebase your branch if you're comfortable with that).

Thanks! We'll try to review your pull request as soon as we can.


## Development

To get set up for development, after cloning this repository:

```sh
npm install && npm run clean
```

You'll need a [local installation of Neo4j](http://neo4j.org/download), and it should be running on the default port of 7474.

To run the tests:

```sh
npm test
```

This library is written in [CoffeeScript](http://coffeescript.org/), and we lint the code with [CoffeeLint](http://coffeelint.org/). To lint:

```sh
npm run lint
```

The tests automatically compile the CoffeeScript on-the-fly, but you can also generate `.js` files from the source `.coffee` files manually:

```sh
npm run build
```

This is in fact what's run on `prepublish` for npm. But please don't check the generated `.js` files in; to remove:

```sh
npm run clean
```

When compiled `.js` files exist, changes to the source `.coffee` files will *not* be picked up automatically; you'll need to rebuild.

If you `npm link` this module and you want the code compiled on-the-fly during development, you can create an `exports.js` file under `lib-new/` with the following:

```js
require('coffee-script/register');
module.exports = require('./exports.coffee');
```

But don't check this in! That would cause all clients to compile the code on-the-fly every time, which isn't desirable in production.


## Testing

This library strives for thorough test coverage. Every major feature has corresponding tests.

The tests run on [Mocha](http://mochajs.org/) and use [Chai](http://chaijs.com/) for assertions. In addition, the code is written in [Streamline.js](https://github.com/Sage/streamlinejs) syntax, for convenience and robustness.

In a nutshell, instead of calling async functions with a callback (which receives an error and a result), we get to call them with an `_` parameter instead — and then pretend as if the functions are synchronous (*returning* their results and *throwing* any errors).

E.g. instead of writing tests like this:

```coffee
it 'should get foo then set bar', (done) ->
    db.getFoo (err, foo) ->
        return done err if err
        expect(foo).to.be.a 'number'

        db.setBar foo, (err, bar) ->
            return done err if err
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

It's important for our tests to pass across multiple versions of Neo4j, and they should also be robust to existing data (e.g. labels and constraints) in the database. To that end, they should generate data for testing, and then clean up that data at the end.
