<template>
  <h1>This is the game. You're {{ current_user.nickname }} and facing {{ current_user.other_nickname }}</h1>
  <button @click="quitGame">Quit</button>
</template>

<script>
import {GameCallback, SocketioService} from "@/services/socketio.service";
import {current_user} from "@/store";

export default {
  name: "Game",
  data(){
    let self = this;

    const CALLBACK = new GameCallback(
        async function (msg){
          console.log("<" + current_user.nickname + "> MESSAGE INCOMING: ", msg);

          if(!msg.hasOwnProperty('type')
              || !msg.hasOwnProperty('sender')
              || !msg.hasOwnProperty('recipient')){
            console.log("Received corrupted message", msg);
            return;
          }

          switch (msg.type){
            case 'game_state':{
              if(!msg.hasOwnProperty('value')){
                console.log("Received corrupted message", msg);
                return;
              }

              switch (msg.value){
                case 'quit': {
                  self.$emit('end-game', current_user.other_nickname + " has quit the game.");
                  return;
                }
              }
              break;
            }
          }

          // TODO game logic
        },
        function (err){
          console.log("Received custom error", err);
        },
        function(){
          console.log("Other disconnected.")
          self.$emit('end-game', current_user.other_nickname + " has disconnected.");
        }
    );

    return {
      current_user,
      CALLBACK
    }
  },
  emits: ['end-game', 'popup'],
  methods: {
    quitGame(){
      SocketioService.sendMessage({'type': 'game_state', 'value': 'quit', 'recipient': current_user.other_nickname})
      this.$emit('end-game');
    }
  },
  mounted() {
    console.log("Mounting game...");
    SocketioService.registerHandlers(this.CALLBACK);
  }
}
</script>

<style scoped>

</style>