import { Server } from "socket.io";

const io = new Server(3000, {
    handlePreflightRequest: (req, res) => {
        const headers = {
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Access-Control-Allow-Origin': req.headers.origin,
            'Access-Control-Allow-Credentials': true,
        }
        res.writeHead(200, headers)
        res.end()
    },
});

const all_connections = new Set();

console.log("Listening on port 3000.")

io.on('connect', (socket) => {
    console.log('a user connected with IP', socket.conn.remoteAddress);

    socket.username = "Anonymous";

    all_connections.add(socket);
    all_connections.forEach(c => console.log(c.id, c.username))

    socket.on('disconnect', () => {
        console.log('user disconnected')
        all_connections.delete(socket);
        all_connections.forEach(c => console.log(c.id, c.username))
    })

    socket.on('message', (msg) => {
        console.log(`received message: ${msg}`)
    })
})
