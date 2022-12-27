import { io } from 'socket.io-client';
import * as assert from "assert";

class SocketioService {
    static socket;
    static is_open;
    constructor() {

    }

    public static setupSocketConnection(connectionCallback){
        console.log("Trying to setup socket connection...");
        let self = this;

        // @ts-ignore
        this.socket = io(import.meta.env.VITE_SOCKET_ENDPOINT);

        this.socket.on("error", function (){
            console.log("CLIENT: ERROR :)");
            connectionCallback.on_error();
        });

        this.socket.on("connect", function () {
            console.log("CLIENT: Connected!")
            self.is_open = true;
            connectionCallback.on_connected();
        });

        this.socket.on("disconnect", function (){
            console.log("CLIENT: Disconnected.");
            connectionCallback.on_disconnected();
            self.is_open = false;
        });
    }

    public static closeConnection() {
        this.socket.disconnect();
        delete this.socket;
    }

    public static registerLobbyHandlers(lobbyCallback){
        this.socket.on("message", lobbyCallback.on_message);
        this.socket.on("users_change", lobbyCallback.on_users_change);
        this.socket.on("your_nickname", lobbyCallback.on_your_nickname);
        this.socket.on("custom_error", lobbyCallback.on_custom_error);
    }

    static sendMessage(message) {
        console.log("Trying to send message: ", message);

        if(!this.is_open){
            console.log("WARNING: socket is not open")
            throw new Error(`Message ${JSON.stringify(message)} cannot be sent, because the socket is not opened.`);
        }

        if(!message.hasOwnProperty('recipient')){
            throw new Error(`Message ${JSON.stringify(message)} cannot be sent, because it has no recipient.`);
        }

        this.socket.emit("message", message);
    }
}

class ConnectionCallback {
    on_connected;
    on_error;
    on_disconnected;

    constructor(on_connected, on_disconnected, on_error) {
        this.on_error = on_error;
        this.on_connected = on_connected;
        this.on_disconnected = on_disconnected;
    }
}

class LobbyCallback {
    on_message;
    on_custom_error;
    on_your_nickname;
    on_users_change;

    constructor(on_message, on_custom_error, on_your_nickname, on_users_change) {
        this.on_message = on_message;
        this.on_custom_error = on_custom_error;
        this.on_your_nickname = on_your_nickname;
        this.on_users_change = on_users_change;
    }
}

export {ConnectionCallback, LobbyCallback, SocketioService};