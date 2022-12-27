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
    let users = {};

    for (const [k, v] of Object.entries(all_connections)) {
        users[k] = v.user_object;
    }

    io.emit("users_change", users);
}

function notify_user_state_update(user_nickname) {
    console.log("output socket state", all_connections[user_nickname].user_object);

    io.emit("user_state_update", all_connections[user_nickname].user_object);
}

io.on('connection', (socket) => {
    console.log('a user connected with IP', socket.conn.remoteAddress);

    socket.user_object = {}
    socket.user_object.nickname = generateUsername("-", 2);
    socket.user_object.state = {'state': 'idle', 'other_nickname': null}
    socket.emit("your_nickname", socket.user_object.nickname);
    all_connections[socket.user_object.nickname] = socket;
    notify_users_change();

    socket.on('get-lobby-info', () => {
        socket.emit("your_nickname", socket.user_object.nickname);
        notify_users_change();
    });

    socket.on('my-state', (state) => {
        console.log("input socket state", state, socket.user_object.nickname);
        if(state.hasOwnProperty('state')){
            socket.user_object.state.state = state.state;
        }
        if(state.hasOwnProperty('other_nickname')){
            socket.user_object.state.other_nickname = state.other_nickname;
        }else{
            socket.user_object.state.other_nickname = null;
        }
        notify_user_state_update(socket.user_object.nickname);
    });

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
