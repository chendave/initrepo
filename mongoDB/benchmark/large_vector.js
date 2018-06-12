if ( typeof(tests) != "object" ) {
    tests = [];
}


// variables for vector insert test
// 100 documents per insert
var batchSize = 100;
var docs = [];
for (var i = 0; i < batchSize; i++) {
    docs.push( {x: 1} );
}


// Variables for vector insert of large documents
// 100 documents per batch
batchSize = 100;
// 1024 byte string in the document 
// To verify the impact when the throughput is larger than the cache, use the below config
// var docSize = 10240;
// Verify the disk don't have many impact on the performance when the cache is large enough
var docSize = 1024;
function makeDocument(docSize) {
        var doc = { "fieldName":"" };
        while(Object.bsonsize(doc) < docSize) {
            doc.fieldName += "x";
        }
    return doc;
}

doc = makeDocument(docSize);
var docs = [];
for (var i = 0; i < batchSize; i++) {
    docs.push(doc);
}



/*
 * Setup:
 * Test: Insert a vector of large documents. Each document contains a long string
 * Notes: Generates the _id field on the client. This test should remain the last test in the file. 
 *        
 */
tests.push( { name: "Insert.LargeDocVector",
              tags: ['insert','regression'],
              pre: function( collection ) { collection.drop(); },
              ops: [
                  { op:  "insert",
                    doc: docs }
              ] } );

/*
 * Note: Please do not add tests after Insert.LargeDocVector. Add new tests before it. 
 */
