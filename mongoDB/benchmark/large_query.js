if (typeof(tests) !== "object") {
    tests = [];
}

/**
 * Sets up a collection and/or a view with the appropriate documents and indexes.
 *
 * @param {Boolean} isView - True if 'collectionOrView' is a view; false otherwise.
 * @param {Number} nDocs - The number of documents to insert into the collection.
 * @param {function} docGenerator - A function that takes a document number and returns a document.
 * @param {Object[]} indexes - A list of index specs to create on the collection.
 * @param {Object} collectionOptions - Options to use for view/collection creation.
 */
function collectionPopulator(isView, nDocs, indexes, docGenerator, collectionOptions) {
    return function(collectionOrView) {
        Random.setRandomSeed(258);

        collectionOrView.drop();

        var db = collectionOrView.getDB();
        var collection;
        if (isView) {
            // 'collectionOrView' is a view, so specify a backing collection to serve as its source
            // and perform the view creation.
            var viewName = collectionOrView.getName();
            var collectionName = viewName + "_BackingCollection";
            collection = db.getCollection(collectionName);
            collection.drop();

            var viewCreationSpec = {create: viewName, viewOn: collectionName};
            assert.commandWorked(db.runCommand(Object.extend(viewCreationSpec, collectionOptions)));
        } else {
            collection = collectionOrView;
        }

        var collectionCreationSpec = {create: collection.getName()};
        assert.commandWorked(
            db.runCommand(Object.extend(collectionCreationSpec, collectionOptions)));
        var bulkOp = collection.initializeUnorderedBulkOp();
        for (var i = 0; i < nDocs; i++) {
            bulkOp.insert(docGenerator(i));
        }
        bulkOp.execute();
        indexes.forEach(function(indexSpec) {
            assert.commandWorked(collection.ensureIndex(indexSpec));
        });
        //dave: flush all data into disk
        assert.commandWorked(db.adminCommand({fsync: 1}));
    };
}

/**
 * Rewrites a query op in benchRun format to the equivalent aggregation command op, also in benchRun
 * format.
 */
function rewriteQueryOpAsAgg(op) {
    var newOp = {
        op: "command",
        ns: "#B_DB",
        command: {
            aggregate: "#B_COLL",
            pipeline: [],
            cursor: {}
        }
    };
    var pipeline = newOp.command.pipeline;

    // Special case handling for legacy OP_QUERY find $query syntax. This is used as a workaround to
    // test queries with sorts in a fashion supported by benchRun.
    //
    // TODO SERVER-5722: adding full-blown sort support in benchRun should prevent us from requiring
    // this hack.
    if (op.query && op.query.$query) {
        pipeline.push({$match: op.query.$query});

        if (op.query.$orderby) {
            pipeline.push({$sort: op.query.$orderby});
        }

        return newOp;
    }

    if (op.query) {
        pipeline.push({$match: op.query});
    }

    if (op.skip) {
        pipeline.push({$skip: op.skip});
    }

    if (op.limit) {
        pipeline.push({$limit: op.limit});
    } else if (op.op === "findOne") {
        pipeline.push({$limit: 1});
    }

    // Confusingly, benchRun uses the name "filter" to refer to the projection (*not* the query
    // predicate).
    if (op.filter) {
        pipeline.push({$project: op.filter});
    }

    return newOp;
}

/**
 * Creates test cases and adds them to the global testing array. By default, each test case
 * specification produces several test cases:
 *  - A find on a regular collection.
 *  - A find on an identity view.
 *  - The equivalent aggregation operation on a regular collection.
 *
 * @param {Object} options - Options describing the test case.
 * @param {String} options.name - The name of the test case. "Queries" is prepended for tests on
 * regular collections and "Queries.IdentityView" for tests on views.
 * @param {function} options.docs - A generator function that produces documents to insert into the
 * collection.
 * @param {Object[]} options.op - The operations to perform in benchRun.
 *
 * @param {Boolean} {options.createViewsPassthrough=true} - If false, specifies that a views
 * passthrough test should not be created, generating only one test on a regular collection.
 * @param {Object[]} {options.indexes=[]} - An array of index specifications to create on the
 * collection.
 * @param {String[]} {options.tags=[]} - Additional tags describing this test. The "query" tag is
 * automatically added to test cases for collections. The tags "views" and "query_identityview" are
 * added to test cases for views.
 * @param {Object} {options.collectionOptions={}} - Options to use for view/collection creation.
 */
function addTestCase(options) {
    var isView = true;
    var indexes = options.indexes || [];
    var tags = options.tags || [];

    tests.push({
        tags: ["query"].concat(tags),
        name: "Queries." + options.name,
        pre: collectionPopulator(
            !isView, options.nDocs, indexes, options.docs, options.collectionOptions),
        post: function(collection) {
            collection.drop();
        },
        ops: [options.op]
    });

    //if (options.createViewsPassthrough !== false) {
    //    tests.push({
    //        tags: ["views", "query_identityview"].concat(tags),
    //        name: "Queries.IdentityView." + options.name,
    //        pre: collectionPopulator(
    //            isView, options.nDocs, indexes, options.docs, options.collectionOptions),
    //        post: function(view) {
    //            view.drop();
    //            var collName = view.getName() + "_BackingCollection";
    //            view.getDB().getCollection(collName).drop();
    //        },
    //        ops: [options.op]
    //    });
    //}

    // Generate a test which is the aggregation equivalent of this find operation.
    //tests.push({
    //    tags: ["agg_query_comparison"].concat(tags),
    //    name: "Aggregation." + options.name,
    //    pre: collectionPopulator(
    //        !isView, options.nDocs, indexes, options.docs, options.collectionOptions),
    //    post: function(collection) {
    //        collection.drop();
    //    },
    //    ops: [rewriteQueryOpAsAgg(options.op)]
    //});
}

/**
 * Setup: Create a collection of documents with only an integer _id field.
 *
 * Test: Query for a random document based on _id. Each thread accesses a distinct range of
 * documents.
 */
//addTestCase({
//    name: "IntIdFindOne",
//    tags: ["regression"],
//    nDocs: 4800,
//    docs: function(i) {
//        return {_id: i};
//    },
//    op: {op: "findOne", query: {_id: {"#RAND_INT_PLUS_THREAD": [0, 100]}}}
//});

/**
 * Large string used for generating documents in the LargeDocs test.
 */
var bigString = new Array(1024 * 1024 * 5).toString();

/**
 * Setup: Create a collection with one hundred 5 MiB documents.
 *
 * Test: Do a table scan.
 */
addTestCase({
    name: "LargeDocs",
    nDocs: 100,
    docs: function(i) {
        return {x: bigString};
    },
    op: {op: "find", query: {}}
});

