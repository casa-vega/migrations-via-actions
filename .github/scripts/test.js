const { test } = require('uvu');
const assert = require('uvu/assert');
const fs = require("fs");

const nock = require("nock");
nock.disableNetConnect();

const token = 'secret123';

const repositories = 'https://github.com/mindfulrob/test1' +
                    '\nhttps://github.com/mindfulrob/test2' +
                    '\nhttps://github.com/mindfulrob/test3';

test.before.each(() => {
    // nothing to do here
});
test.after.each(() => {
    // nothing to do here
});

test("Write repo visibility to file", async function () {
    let mock = nock("https://api.github.com");
    mock.get(`/repos/mindfulrob/test1?owner=mindfulrob&repo=test1`)
        .reply(201, {visibility: "internal"});
    mock.get(`/repos/mindfulrob/test2?owner=mindfulrob&repo=test2`)
        .reply(201, {visibility: "internal"});
    mock.get(`/repos/mindfulrob/test3?owner=mindfulrob&repo=test3`)
        .reply(201, {visibility: "internal"});

    await require('./get-source-repos-visibility.js')({token, repositories});
    assert.equal(mock.pendingMocks(), []);
});

test.run();