require('streamline');

// TODO when streamline supports it, be explicit in requires?
// e.g. require('./tests_') instead of require('./tests')

module.exports = {
    
    'test CRUD': require('./crud'),
    
    'test serialization': require('./serialization'),
    
};
