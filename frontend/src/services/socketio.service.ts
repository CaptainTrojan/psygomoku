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
        this.socket.on("user_state_update", lobbyCallback.on_user_state_update);
        this.socket.on("your_nickname", lobbyCallback.on_your_nickname);
        this.socket.on("custom_error", lobbyCallback.on_custom_error);
        this.socket.on("other_disconnected", lobbyCallback.on_other_disconnected);
    }

    public static unregisterAuxiliaryHandlers(){
        this.socket.off("message");
        this.socket.off("users_change");
        this.socket.off("users_state_update");
        this.socket.off("your_nickname");
        this.socket.off("custom_error");
        this.socket.off("other_disconnected");
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

    static getLobbyInfo() {
        this.socket.emit("get-lobby-info");
    }

    static setState(state: string, nickname: string, other_nickname?: string) {
        this.socket.emit("my-state", {'state': state, 'other_nickname': other_nickname})
    }

    static registerGameHandlers(gameCallback: GameCallback) {

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
    on_user_state_update;
    on_other_disconnected;

    constructor(on_message, on_custom_error, on_your_nickname,
                on_users_change, on_user_state_update, on_other_disconnected) {
        this.on_message = on_message;
        this.on_custom_error = on_custom_error;
        this.on_your_nickname = on_your_nickname;
        this.on_users_change = on_users_change;
        this.on_user_state_update = on_user_state_update;
        this.on_other_disconnected = on_other_disconnected;
    }
}

class GameCallback {
    on_message;
    on_custom_error;
    on_other_disconnected;

    constructor(on_message, on_custom_error, on_other_disconnected) {
        this.on_message = on_message;
        this.on_custom_error = on_custom_error;
        this.on_other_disconnected = on_other_disconnected;
    }
}

export {ConnectionCallback, LobbyCallback, SocketioService, GameCallback};