const http = require('node:http');
const { Pool } = require('pg');

function createServer({ query, version }) {
    return http.createServer(async (request, response) => {
        response.setHeader('Content-Type', 'application/json; charset=utf-8');

        if (request.method !== 'GET') {
            response.writeHead(405);
            response.end(JSON.stringify({ error: 'Method not allowed' }));
            return;
        }

        if (request.url === '/') {
            response.writeHead(200);
            response.end(JSON.stringify({ application: 'websolutions-api', version }));
            return;
        }

        if (request.url === '/health') {
            try {
                await query('SELECT 1');
                response.writeHead(200);
                response.end(JSON.stringify({ status: 'ok', database: 'ok', version }));
            } catch {
                response.writeHead(503);
                response.end(JSON.stringify({ status: 'unavailable', database: 'error', version }));
            }
            return;
        }

        response.writeHead(404);
        response.end(JSON.stringify({ error: 'Not found' }));
    });
}

if (require.main === module) {
    const pool = new Pool({
        host: process.env.DB_HOST || 'db',
        port: 5432,
        database: process.env.DB_NAME || 'websolutions',
        user: process.env.DB_USER || 'websolutions',
        password: process.env.DB_PASSWORD
    });

    const server = createServer({
        query: (sql) => pool.query(sql),
        version: process.env.APP_VERSION || 'dev'
    });

    server.listen(3000, '0.0.0.0', () => {
        console.log('WebSolutions API listening on port 3000');
    });
}

module.exports = { createServer };