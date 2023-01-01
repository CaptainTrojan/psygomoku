<template>
  <button @click="quitGame">Quit</button>
  <div>
    <span :class="{game_white: current_user.is_white, game_black: ! current_user.is_white}">You: {{ current_user.nickname }}</span>
    <span :class="{game_white: ! current_user.is_white, game_black: current_user.is_white}" style="float: right;">Enemy: {{ current_user.other_nickname }}</span>
  </div>
  <PsyGomoku @set-status="setStatus" @send-message="sendMessage" ref="psygomoku_game"/>
  <div>
    <span id="status_bar" ref="status_bar">Game loaded.</span>
  </div>

</template>

<script>
import {GameCallback, SocketioService} from "@/services/socketio.service";
import {current_user} from "@/store";
import PsyGomoku from "@/components/play/PsyGomoku.vue";

export default {
  name: "Game",
  computed: {
    current_user() {
      return current_user
    }
  },
  components: {PsyGomoku},
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
          case 'game_state': {
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
          default: {
            self.$refs.psygomoku_game.handleMessage(msg);
            break;
          }
        }
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
    },
    sendMessage(message){
      SocketioService.sendMessage(message);
    },
    setStatus(message){
      this.$refs.status_bar.innerText = message;
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