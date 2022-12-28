import { io } from 'socket.io-client';

class SocketioService {
    static socket;
    private static is_open;
    private static registered_auxiliary_handlers = [];
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

    public static registerHandlers(genericCallback){
        // console.log("Registering handlers... have", this.registered_auxiliary_handlers);
        this.unregisterAuxiliaryHandlers();
        for(const [name, fn] of Object.entries(genericCallback.hooks)){
            this.socket.on(name, fn);
            this.registered_auxiliary_handlers.push(name);
        }
        // console.log("Registered", this.registered_auxiliary_handlers);
    }

    private static unregisterAuxiliaryHandlers(){
        for(let h of this.registered_auxiliary_handlers){
            this.socket.off(h);
        }
        this.registered_auxiliary_handlers.length = 0;
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

class AuxiliaryCallback {
    hooks = {};
}

class LobbyCallback extends AuxiliaryCallback {
    constructor(on_message, on_custom_error, on_your_nickname,
                on_users_change, on_user_state_update, on_other_disconnected) {
        super();
        this.hooks['message'] = on_message;
        this.hooks['custom_error'] = on_custom_error;
        this.hooks['your_nickname'] = on_your_nickname;
        this.hooks['users_change'] = on_users_change;
        this.hooks['user_state_update'] = on_user_state_update;
        this.hooks['other_disconnected'] = on_other_disconnected;
    }
}

class GameCallback extends AuxiliaryCallback {
    constructor(on_message, on_custom_error, on_other_disconnected) {
        super();
        this.hooks['message'] = on_message;
        this.hooks['custom_error'] = on_custom_error;
        this.hooks['other_disconnected'] = on_other_disconnected;
    }
}



export {ConnectionCallback, LobbyCallback, SocketioService, GameCallback};