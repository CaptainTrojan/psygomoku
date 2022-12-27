import { Server } from "socket.io";
import { generateUsername } from "unique-username-generator";

const io = new Server(3000, {
    cors: {
        origin: "*", // TODO!
    }
});

const all_connections = {};
console.log("Listening on port 3000.")

function notify_users_change() {
    let sockets = Object.values(all_connections);
    io.emit("users_change", sockets.map(s => s.user_object));
    console.log("Remaining users (" + sockets.length + "):")
    sockets.forEach(s => console.log(s.user_object));
}

io.on('connection', (socket) => {
    console.log('a user connected with IP', socket.conn.remoteAddress);

    socket.user_object = {}
    socket.user_object.nickname = generateUsername("-", 2);
    socket.emit("your_nickname", socket.user_object.nickname);
    all_connections[socket.user_object.nickname] = socket;
    notify_users_change();

    socket.on('disconnect', () => {
        console.log('user disconnected')
        delete all_connections[socket.user_object.nickname];
        notify_users_change();
    });

    socket.on('message', (msg) => {
        if(msg === null){
            console.log("Received null message! wtf?")
            return;
        }
        msg.sender = socket.user_object.nickname;
        console.log(`received message`, msg)
        if(msg.hasOwnProperty('recipient') &&
            msg.recipient !== msg.sender &&
            all_connections[msg.recipient] !== undefined){

            all_connections[msg.recipient].emit('message', msg);
        }else{
            socket.emit("custom_error",
                {'type': 'message', 'sender': msg.sender, 'options': Object.keys(all_connections)});
        }
    })
})
