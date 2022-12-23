import { io } from 'socket.io-client';

class SocketioService {
    static socket;
    constructor() {

    }

    public static setupSocketConnection(connectionCallback){
        console.log("Trying to setup socket connection...");

        // @ts-ignore
        this.socket = io(import.meta.env.VITE_SOCKET_ENDPOINT);

        this.socket.on("error", function (){
            console.log("CLIENT: ERROR :)");
            connectionCallback.on_error();
        });

        this.socket.on("connect", function () {
            console.log("CLIENT: Connected!")
            connectionCallback.on_connected();
        });

        this.socket.on("disconnect", function (){
            console.log("CLIENT: Disconnected.");
            connectionCallback.on_disconnected();
        });
    }

    public static closeConnection() {
        this.socket.disconnect();
        delete this.socket;
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

export {ConnectionCallback, SocketioService};