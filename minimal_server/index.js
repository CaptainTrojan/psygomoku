const { Server } = require("socket.io");
const { createServer } = require("http");

const httpServer = createServer();
const io = new Server(httpServer, {
  cors: {
    origin: "http://127.0.0.1:5173"
  }
});

const connected_sockets = new Set();

io.on("connection", (socket) => {
    console.log("New connection!");
    connected_sockets.add(socket.id);

    io.emit("players", JSON.stringify(connected_sockets));
    console.log("remaining:", connected_sockets);

    socket.on('disconnect', function () {
    console.log('A user disconnected');
    connected_sockets.delete(socket.id);
        io.emit("players", JSON.stringify(connected_sockets));
        console.log("remaining:", connected_sockets);
    });
});

io.listen(3000);
console.log("listening on 3000");