require('streamline');

console.log('Running tests...');
require('./crud');
require('./serialization');
console.log('Finished running tests.');

/*
module.exports = {
    
    // TODO when streamline supports it, be explicit: require('./tests_')
    'test CRUD': require('./crud'),
    
    'test serialization': require('./serialization'),
    
};
*/

/*
console.log('does it work?!?!');
require('./foo')();
*/

/*
module.exports = {
    'test func': function () { console.log('yes!'); },
    'test foo': require('./foo'),
};
*/