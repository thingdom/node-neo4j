require('streamline');

// TODO: Once streamline supports it, be explicit in requires?
// i.e. require('./tests_') instead of require('./tests')

module.exports = {
    'test CRUD': require('./crud'),
    'test serialization': require('./serialization'),
};
