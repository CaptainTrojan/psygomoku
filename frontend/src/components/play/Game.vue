<template>
  <h1>This is the game. You're {{ current_user.nickname }} and facing {{ current_user.other_nickname }}</h1>
  <button @click="$emit('end-game')">Quit</button>
</template>

<script>
import {GameCallback, SocketioService} from "@/services/socketio.service";
import {current_user} from "@/store";

export default {
  name: "Game",
  data(){
    return {
      current_user
    }
  },
  emits: ['end-game'],
  beforeMount() {
    console.log("Mounting game...");
    let self = this;
    SocketioService.registerGameHandlers(
      new GameCallback(
        async function (msg){
          console.log("<" + current_user.nickname + "> MESSAGE INCOMING: ", msg);

          if(!msg.hasOwnProperty('type')
              || !msg.hasOwnProperty('sender')
              || !msg.hasOwnProperty('recipient')){
            console.log("Received corrupted message", msg);
            return;
          }


        },
        function (err){
          console.log("Received custom error", err);
        },
        function(){
          console.log("Other disconnected.")
          self.$emit('end-game', current_user.other_nickname + " has disconnected.");
        }
      )
    );
  }, // TODO mount order?
  beforeUnmount() {
    SocketioService.unregisterAuxiliaryHandlers();
    console.log("Unmounted game.");
  }
}
</script>

<style scoped>

</style>