import { Server } from "socket.io";

const io = new Server(3000, {
    cors: {
        origin: "*", // TODO!
    }
});

const all_connections = new Set();

console.log("Listening on port 3000.")

io.on('connection', (socket) => {
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
