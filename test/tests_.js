// tests_.js
// Test cases for node-neo4j, written in Streamline.js syntax: https://github.com/Sage/streamlinejs

var assert = require('assert');
var neo4j = require('../lib/neo4j.js');

// database
var DB_HOST = 'localhost';
var DB_PORT = 7474;
var db = new neo4j.Client(DB_HOST, DB_PORT, true);

// data
var data = {
    name: 'Daniel Gasienica',
    magicNumber: 42,
    lovesIceCream: true,
};
var newData = {
    name: 'Daniel Gasienica',
    father: {
        firstName: 'Jan',
        lastName: 'Gasienica'
    },
    tired: false,
};


// TEST SETUP

// sanity output to make sure our tests ran!
console.log('Running tests...');


// TEST CRUD (create, read, update, delete)

// don't bother try-catching; we want errors to propogate.
// note that createNode() returns a string url, whereas getNode() returns a data object!
// TODO createNode() should return a data object too; update this test in that case.
var url1 = db.createNode(data, _);
var id = getNodeId(url1);

var res2 = db.getNode(id, _);
assert.deepEqual(res2, data, 'Retrieved data does not match original data.');

var res3 = db.updateNode(id, newData, _);
var res4 = db.getNode(id, _);
assert.deepEqual(res4, newData, 'Retrieved data does not match updated data.');

db.deleteNode(id, _);

try {
    db.getNode(id, _);
    assert.fail('Found node even though it was deleted.');
} catch (err) {
    assert.strictEqual(err.statusCode, 404, 'Nonexistent node returned non-404 error.');
}


// TEST SERIALIZE/DESERIALIZE

function transform(o) {
    return neo4j.deserialize(neo4j.serialize(o));
}

assert.deepEqual(transform(data), data);
assert.deepEqual(transform(newData), newData);

var o;

// numbers
o = 1;
assert.strictEqual(transform(o), o);

// strings
o = "gasi";
assert.strictEqual(transform(o), o);

// booleans
o = true;
assert.strictEqual(transform(o), o);

// Arrays are not supported
o = [true, false, true];
assert.throws(transform(o));

// Using illegal separator '.' in object key should fail
o = {"this.that": "shouldn't work"};
assert.notDeepEqual(transform(o), o);

// prune database
// for (var i = 0; i < 1000; i++) {
//     db.deleteNode(i, function (err) {});
// }


// TEST TEARDOWN

// sanity output to make sure we reached the end!
console.log('Finished running tests.');


// HELPERS

function print(error, result) {
    console.log(error || result || '');
};

function getNodeId(url) {
    var NODE_REGEX = /node\/(\d+)/g;
    var match = NODE_REGEX.exec(url);
    return match ? parseInt(match[1]) : null;
}
