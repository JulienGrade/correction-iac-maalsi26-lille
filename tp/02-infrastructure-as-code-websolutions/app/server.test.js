const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('./server');

const expectedVersion = process.env.EXPECTED_VERSION || 'test-1.0.0';

async function withServer(query, check) {
    const server = createServer({ query, version: 'test-1.0.0' });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));

    try {
        const address = server.address();
        await check(`http://127.0.0.1:${address.port}`);
    } finally {
        await new Promise((resolve) => server.close(resolve));
    }
}

test('la racine indique la version livrée', async () => {
    await withServer(async () => {}, async (url) => {
        const response = await fetch(url);
        assert.equal(response.status, 200);
        assert.deepEqual(await response.json(), {
            application: 'websolutions-api',
            version: expectedVersion
        });
    });
});

test('la santé est OK quand PostgreSQL répond', async () => {
    await withServer(async () => ({ rows: [{ '?column?': 1 }] }), async (url) => {
        const response = await fetch(`${url}/health`);
        assert.equal(response.status, 200);
        assert.deepEqual(await response.json(), {
            status: 'ok',
            database: 'ok',
            version: 'test-1.0.0'
        });
    });
});

test('la santé est indisponible quand PostgreSQL échoue', async () => {
    await withServer(async () => {
        throw new Error('Database unavailable');
    }, async (url) => {
        const response = await fetch(`${url}/health`);
        assert.equal(response.status, 503);
        assert.deepEqual(await response.json(), {
            status: 'unavailable',
            database: 'error',
            version: 'test-1.0.0'
        });
    });
});