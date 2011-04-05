// serialization_.js
// Test cases for serializing and deserializing data.
// Written in Streamline.js syntax: https://github.com/Sage/streamlinejs

var assert = require('assert');
var db = require('./setup');
var neo4j = require('../lib/neo4j');

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
